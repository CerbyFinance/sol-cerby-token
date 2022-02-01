// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import "./openzeppelin/access/AccessControlEnumerable.sol";

interface IMintableBurnableToken {
    function balanceOf(address account) external returns (uint256);

    function mintByBridge(address to, uint256 amount) external;

    function burnByBridge(address from, uint256 amount) external;
}

contract CrossChainBridgeV2_Test is AccessControlEnumerable {
    event ProofOfBurn(
        bytes mintToken,
        bytes burnToken,
        bytes mintCaller,
        bytes burnCaller,
        uint256 burnAmount,
        uint256 burnNonce,
        ChainType mintChainType,
        uint32 mintChainId,
        ChainType burnChainType,
        uint32 burnChainId,
        bytes32 burnProofHash
    );

    event ProofOfMint(
        bytes mintToken,
        bytes burnToken,
        bytes mintCaller,
        bytes burnCaller,
        uint256 burnAmount,
        ChainType mintChainType,
        uint32 mintChainId,
        ChainType burnChainType,
        uint32 burnChainId,
        bytes32 burnProofHash
    );

    event ApprovedBurnProof(bytes32 burnProofHash);

    enum States {
        DefaultValue,
        Burned,
        Approved,
        Executed
    }

    enum ChainType {
        Undefined,
        Evm,
        Casper,
        Solana,
        Radix
    }

    enum Allowance {
        Undefined,
        Allowed,
        Blocked
    }

    ChainType thisChainType;

    // it's common storage for all chains (evm, casper, solana etc)
    // also it can be splitted in two storages (src and dest)
    mapping(bytes32 => States) public burnProofStorage;
    mapping(address => uint32) public nonceByToken;
    mapping(bytes32 => Allowance) public allowances;

    constructor() {
        thisChainType = ChainType.Evm;
    }

    function setAllowance(
        bytes memory mintGenericToken,
        bytes memory burnGenericToken,
        ChainType mintChainType,
        uint32 mintChainId,
        ChainType burnChainType,
        uint32 burnChainId
    ) external {
        bytes32 allowanceHash = getAllowanceHash(
            mintGenericToken,
            burnGenericToken,
            mintChainType,
            mintChainId,
            burnChainType,
            burnChainId
        );

        allowances[allowanceHash] = Allowance.Allowed;
    }

    function getAllowanceHash(
        bytes memory mintGenericToken,
        bytes memory burnGenericToken,
        ChainType mintChainType,
        uint32 mintChainId,
        ChainType burnChainType,
        uint32 burnChainId
    ) private view returns (bytes32) {
        bytes memory mintBytes = abi.encodePacked(
            mintGenericToken,
            mintChainType,
            mintChainId
        );
        bytes memory burnBytes = abi.encodePacked(
            burnGenericToken,
            burnChainType,
            burnChainId
        );

        if (sha256(mintBytes) > sha256(burnBytes)) {
            return sha256(abi.encodePacked(mintBytes, burnBytes));
        }

        return sha256(abi.encodePacked(burnBytes, mintBytes));
    }

    // 40 bytes
    function genericAddress(address some) private pure returns (bytes memory) {
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
        address mintToken,
        bytes memory burnGenericToken,
        bytes memory burnGenericCaller,
        uint8 burnChainType,
        uint32 burnChainId,
        uint256 burnAmount,
        uint256 burnNonce,
        bytes32 burnProofHash
    ) external {
        require(burnGenericToken.length == 40, "invalid caller length");
        require(burnGenericCaller.length == 40, "invalid token length");

        bytes memory mintGenericCaller = genericAddress(msg.sender);
        bytes memory mintGenericToken = genericAddress(mintToken);

        {
            bytes32 allowanceHash = getAllowanceHash(
                mintGenericToken,
                burnGenericToken,
                thisChainType,
                uint32(block.chainid),
                ChainType(burnChainType),
                burnChainId
            );

            require(
                allowances[allowanceHash] == Allowance.Allowed,
                "allowance not found"
            );
        }

        require(
            burnProofStorage[burnProofHash] == States.Approved,
            "CCB: Proof is not approved or already executed"
        );

        // prettier-ignore
        bytes memory packed = abi.encodePacked(
            mintGenericCaller, burnGenericCaller,
            mintGenericToken, burnGenericToken,
            burnAmount,
            uint8(thisChainType), uint32(block.chainid),
            burnChainType, burnChainId,
            burnNonce
        );

        require(
            packed.length == 40 + 40 + 40 + 40 + 32 + 1 + 4 + 1 + 4 + 32,
            "package is invalid"
        );

        bytes32 computedBurnProofHash = sha256(packed);

        require(
            computedBurnProofHash == burnProofHash,
            "CCB: Provided hash is invalid"
        );

        burnProofStorage[burnProofHash] = States.Executed;

        IMintableBurnableToken(mintToken).mintByBridge(msg.sender, burnAmount);

        {
            ChainType _burnChainType = ChainType(burnChainType);
            uint32 _burnChainId = burnChainId;
            emit ProofOfMint(
                mintGenericToken,
                burnGenericToken,
                mintGenericCaller,
                burnGenericCaller,
                burnAmount,
                thisChainType,
                uint32(block.chainid),
                _burnChainType,
                _burnChainId,
                computedBurnProofHash
            );
        }
    }

    function burnAndCreateProof(
        address burnToken,
        bytes memory mintGenericToken,
        bytes memory mintGenericCaller,
        uint256 burnAmount,
        uint8 mintChainType,
        uint32 mintChainId
    ) external {
        require(mintGenericCaller.length == 40, "invalid caller length");
        require(mintGenericToken.length == 40, "invalid token length");

        bytes memory burnGenericCaller = genericAddress(msg.sender);
        bytes memory burnGenericToken = genericAddress(burnToken);

        // stack to deep fix
        {
            bytes32 allowanceHash = getAllowanceHash(
                mintGenericToken,
                burnGenericToken,
                ChainType(mintChainType),
                mintChainId,
                ChainType(thisChainType),
                uint32(block.chainid)
            );

            require(
                allowances[allowanceHash] == Allowance.Allowed,
                "allowance not found"
            );
        }

        require(
            burnAmount <=
                IMintableBurnableToken(burnToken).balanceOf(msg.sender),
            "CCB: Amount must not exceed available balance. Try reducing the amount."
        );

        uint256 burnNonce = nonceByToken[burnToken];

        // prettier-ignore
        bytes memory packed = abi.encodePacked(
            mintGenericCaller, burnGenericCaller,
            mintGenericToken, burnGenericToken,
            burnAmount,
            mintChainType, mintChainId,
            uint8(thisChainType), uint32(block.chainid),
            burnNonce
        );

        require(
            packed.length == 40 + 40 + 40 + 40 + 32 + 1 + 4 + 1 + 4 + 32,
            "package is invalid"
        );

        bytes32 computedBurnProofHash = sha256(packed);

        burnProofStorage[computedBurnProofHash] = States.Burned;

        IMintableBurnableToken(burnToken).burnByBridge(msg.sender, burnAmount);

        emit ProofOfBurn(
            mintGenericToken,
            burnGenericToken,
            mintGenericCaller,
            burnGenericToken,
            burnAmount,
            burnNonce,
            ChainType(mintChainType),
            mintChainId,
            thisChainType,
            uint32(block.chainid),
            computedBurnProofHash
        );

        nonceByToken[burnToken]++;

        // return computedBurnProofHash;
    }
}
