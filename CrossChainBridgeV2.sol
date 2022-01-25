// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "./openzeppelin/access/AccessControlEnumerable.sol";


interface IMintableBurnableToken {
    function balanceOf(address account) external returns (uint);

    function mintByBridge(address to, uint256 amount) external;
    function burnByBridge(address from, uint256 amount) external;
}

contract CrossChainBridgeV2 is AccessControlEnumerable {
    event ProofOfBurn(
        bytes     srcToken,
        bytes     destToken,
        bytes     srcCaller,
        bytes     destCaller,
        uint256   srcAmount,
        uint256   srcNonce,
        ChainType srcChainType,
        uint32    srcChainId,
        ChainType destChainType,
        uint32    destChainId,
        bytes32   burnProofHash
    );

    event ProofOfMint(
        bytes     srcToken,
        bytes     destToken,
        bytes     srcCaller,
        bytes     destCaller,
        uint256   destAmount,
        // destNonce ?
        ChainType srcChainType,
        uint32    srcChainId,
        ChainType destChainType,
        uint32    destChainId,
        bytes32   burnProofHash
    );

    event ApprovedBurnProof(bytes32 burnProofHash);

    enum States {
        DefaultValue,
        Burned,
        Approved,
        Executed
    }

    enum ChainType {
        Undefined, Evm, Casper, Solana, Radix 
    }

    enum Allowance {
        Undefined,
        Allowed,
        Blocked
    }

    ChainType _srcChainType;

    // it's common storage for all chains (evm, casper, solana etc)
    // also it can be splitted in two storages (src and dest)
    mapping(bytes32 => States) public burnProofStorage;
    mapping(address => uint32) public srcNonceByToken;
    mapping(bytes32 => Allowance) public allowances;

    constructor() {
        _srcChainType = ChainType.Evm;
        
    }

    function setAllowance(
        address       srcToken,
        bytes memory  destToken,
        ChainType     destChainType,
        uint32        destChainId
    ) external {
        bytes32 allowanceHash = getAllowanceHash(
            destChainType,
            destChainId,
            genericAddress(srcToken),
            destToken
        );

        allowances[allowanceHash] = Allowance.Allowed;
    }


    function getAllowanceHash(
        ChainType     destChainType,
        uint32        destChainId,
        bytes memory  srcToken,
        bytes memory  destToken
    ) private view returns(bytes32) {
        return sha256(abi.encodePacked(
            uint8(_srcChainType),
            uint32(block.chainid),
            uint8(destChainType),
            destChainId,
            srcToken,
            destToken
        ));
    }

    // 40 bytes
    function genericAddress(address some) private pure returns(bytes memory) {
        bytes memory result = new bytes(40);
        assembly {
            mstore(add(result, 40), some)
        }
        return result;
    }

    function approveBurnProof(bytes32 proofHash) external {
        require(
            burnProofStorage[proofHash] == States.DefaultValue,
            "CCB: Already approved"
        );
        burnProofStorage[proofHash] = States.Approved;
        emit ApprovedBurnProof(proofHash);
    }

    function mintWithBurnProof(
        address      _srcToken,
        bytes memory destToken,  
        bytes memory destCaller,
        uint8        destChainType,
        uint32       destChainId,
        bytes32      destBurnProofHash,
        uint256      destAmount,
        uint256      destNonce
    ) external {
        require(destCaller.length == 40, "invalid caller length");
        require(destToken.length == 40,  "invalid token length");

        bytes memory srcCaller = genericAddress(msg.sender);
        bytes memory srcToken = genericAddress(_srcToken);

        {
            bytes32 allowanceHash = getAllowanceHash(
                ChainType(destChainType),
                destChainId,
                srcToken,
                destToken
            );

            require(
                allowances[allowanceHash] == Allowance.Allowed,
                "allowance not found"
            );
        }

        require(
            burnProofStorage[destBurnProofHash] == States.Approved,
            "CCB: Proof is not approved or already executed"
        );

        bytes memory packed = abi.encodePacked(
            srcToken, destToken, 
            srcCaller, destCaller,
            destAmount,
            uint8(_srcChainType), uint32(block.chainid), // srcChainType, srcChainId
            destChainType, destChainId,
            destNonce
        );

        require(packed.length == 40 + 40 + 40 + 40 + 32 + 1 + 2 + 1 + 2 + 32, "package is invalid");

        bytes32 computedBurnProofHash = sha256(packed);

        require(computedBurnProofHash == destBurnProofHash, "CCB: Provided hash is invalid");

        burnProofStorage[destBurnProofHash] = States.Executed;

        IMintableBurnableToken(_srcToken).mintByBridge(msg.sender, destAmount);

        {
            ChainType _destChainType = ChainType(destChainType);
            uint32 _destChainId = destChainId;
            emit ProofOfMint(
                srcToken,
                destToken,
                srcCaller,
                destCaller,
                destAmount,
                // destNonce ?
                _srcChainType,
                uint32(block.chainid),
                _destChainType,
                _destChainId,
                computedBurnProofHash
            );
        }
    }

     function burnAndCreateProof(
        address      _srcToken,
        bytes memory destToken, 
        bytes memory destCaller,
        uint256 srcAmount,
        uint8   destChainType,
        uint32  destChainId
    ) external {
        require(destCaller.length == 40, "invalid caller length");
        require(destToken.length == 40,  "invalid token length");

        bytes memory srcCaller = genericAddress(msg.sender);
        bytes memory srcToken = genericAddress(_srcToken);

        // stack to deep fix
        {
            bytes32 allowanceHash = getAllowanceHash(
                ChainType(destChainType),
                destChainId,
                srcToken,
                destToken
            );

            require(
                allowances[allowanceHash] == Allowance.Allowed,
                "allowance not found"
            );
        }

        require(
            srcAmount <= IMintableBurnableToken(_srcToken).balanceOf(msg.sender),
            "CCB: Amount must not exceed available balance. Try reducing the amount."
        );

        uint256 srcNonce = srcNonceByToken[_srcToken];

        bytes memory packed  = abi.encodePacked(
            srcToken, destToken, 
            srcCaller, destCaller,
            srcAmount,
            uint8(_srcChainType), uint32(block.chainid), // srcChainType, srcChainId
            destChainType, destChainId,
            srcNonce
        );

        require(packed.length == 40 + 40 + 40 + 40 + 32 + 1 + 2 + 1 + 2 + 32, "package is invalid");

        bytes32 computedBurnProofHash = sha256(packed);

        burnProofStorage[computedBurnProofHash] = States.Burned;

        IMintableBurnableToken(_srcToken).burnByBridge(msg.sender, srcAmount);

        emit ProofOfBurn(
            srcToken,
            destToken,
            srcCaller,
            destCaller,
            srcAmount,
            srcNonce,
            _srcChainType,
            uint32(block.chainid),
            ChainType(destChainType),
            destChainId,
            computedBurnProofHash
        );

        srcNonceByToken[_srcToken]++;

        // return computedBurnProofHash;
    }
}
