// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControlEnumerable.sol";


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
        ChainType destChainType,
        uint16    destChainId,
        bytes32   burnProofHash
    );

    event ProofOfMint(
        bytes     srcToken,
        bytes     destToken,
        bytes     srcCaller,
        bytes     destCaller,
        uint256   destAmount,
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

    address public _srcToken; // original format (20 bytes, or 32 bytes in case of casper)
    ChainType _srcChainType;

    // it's common storage for all chains (evm, casper, solana etc)
    // also it can be splitted in two storages (src and dest)
    mapping(bytes32 => States) public burnProofStorage;
    mapping(address => uint256) public srcNonceByToken;

    constructor() {
        _srcToken = address(1);
        _srcChainType = ChainType.Evm;
    }

    function getSrcCaller() private view returns(bytes memory) {
        bytes memory srcCaller = new bytes(40); 
        address _srcCaller = msg.sender;
        assembly {
            mstore(
                add(
                    srcCaller,
                    40
                ),
                _srcCaller
            )
        }

        return srcCaller;
    }

    function getSrcToken() private view returns(bytes memory) {
        bytes memory srcToken = new bytes(40);
        address __srcToken = _srcToken; // **
        assembly {
            mstore(
                add(
                    srcToken,
                    40
                ),
                __srcToken // ** or use .slot ?
            )
        }

        return srcToken;
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
        bytes memory destToken,  
        bytes memory destCaller,
        uint8     destChainType,
        uint16    destChainId,
        bytes32   destBurnProofHash,
        uint256   destAmount,
        uint256   destNonce
    ) external {
        require(
            burnProofStorage[destBurnProofHash] == States.Approved,
            "CCB: Proof is not approved or already executed"
        );

        require(destCaller.length == 40, "invalid caller length");
        require(destToken.length == 40,  "invalid token length");

        // or ignore ?
        // TODO: require(destChainType is ChainType) 

        bytes memory srcCaller = getSrcCaller();
        bytes memory srcToken = getSrcToken();

        bytes memory packed = abi.encodePacked(
            srcCaller, destCaller,
            srcToken, destToken, 
            destAmount,
            uint8(_srcChainType), uint16(block.chainid), // srcChainType, srcChainId
            destChainType, destChainId,
            destNonce
        );

        require(packed.length == 40 + 40 + 40 + 40 + 32 + 1 + 2 + 1 + 2 + 32, "package is invalid");

        bytes32 computedBurnProofHash = sha256(packed);

        require(computedBurnProofHash == destBurnProofHash, "CCB: Provided hash is invalid");

        burnProofStorage[destBurnProofHash] = States.Executed;

        IMintableBurnableToken(_srcToken).mintByBridge(msg.sender, destAmount);

        emit ProofOfMint(
            srcToken,
            destToken,
            srcCaller,
            destCaller,
            destAmount,
            destBurnProofHash
        );
    }

     function burnAndCreateProof(
        bytes memory destToken, 
        bytes memory destCaller,
        uint256 srcAmount,
        uint8   destChainType,
        uint16  destChainId
    ) external {
        IMintableBurnableToken iCerbyToken = IMintableBurnableToken(_srcToken);
        require(
            srcAmount <= iCerbyToken.balanceOf(msg.sender),
            "CCB: Amount must not exceed available balance. Try reducing the amount."
        );

        require(destCaller.length == 40, "invalid caller length");
        require(destToken.length == 40,  "invalid token length");

        // or ignore ?
        // TODO: require(destChainType is ChainType)

        bytes memory srcCaller = getSrcCaller();
        bytes memory srcToken = getSrcToken();

        bytes memory packed = abi.encodePacked(
            srcCaller, destCaller,
            srcToken, destToken, 
            srcAmount,
            uint8(_srcChainType), uint16(block.chainid), // srcChainType, srcChainId
            destChainType, destChainId,
            srcNonceByToken[_srcToken]
        );

        require(packed.length == 40 + 40 + 40 + 40 + 32 + 1 + 2 + 1 + 2 + 32, "package is invalid");

        bytes32 computedBurnProofHash = sha256(packed);

        burnProofStorage[computedBurnProofHash] = States.Burned;

        iCerbyToken.burnByBridge(msg.sender, srcAmount);

        emit ProofOfBurn(
            srcToken,
            destToken,
            srcCaller,
            destCaller,
            srcAmount,
            srcNonceByToken[_srcToken],
            ChainType(destChainType),
            destChainId,
            computedBurnProofHash
        );
        srcNonceByToken[_srcToken]++;
    }
}