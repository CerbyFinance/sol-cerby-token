// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.11;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/ICerbyTokenMinterBurner.sol";

contract CerbyBridgeV2 is AccessControlEnumerable {
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

    error CerbyBridgeV2_InvalidPackageLength();
    error CerbyBridgeV2_AmountMustNotExceedAvailableBalance();
    error CerbyBridgeV2_DirectionAllowanceWasNotFound();
    error CerbyBridgeV2_InvalidDestinationTokenLength();
    error CerbyBridgeV2_InvalidDestinationCallerLength();
    error CerbyBridgeV2_AlreadyApproved();
    error CerbyBridgeV2_ProofIsNotApprovedOrAlreadyExecuted();
    error CerbyBridgeV2_ProvidedHashIsInvalid();

    ChainType _srcChainType;

    // it's common storage for all chains (evm, casper, solana etc)
    // also it can be splitted in two storages (src and dest)
    mapping(bytes32 => States) public burnProofStorage;
    mapping(address => uint32) public srcNonceByToken;
    mapping(bytes32 => Allowance) public allowances;

    mapping(uint => uint) public chainIdToFee;
    uint constant DEFAULT_FEE = 5e18; // 5 cerUSD fee
    address constant CER_USD_CONTRACT = address(0);

    constructor() {
        _srcChainType = ChainType.Evm;     

        chainIdToFee[1] = 50e18; // 50 cerUSD to ethereum   
    }

    function setChainsToFee(uint[] calldata chainIds, uint fee)
        public
        onlyRole(ROLE_ADMIN)
    {
        for(uint i; i<chainIds.length; i++) {
            chainIdToFee[chainIds[i]] = fee;
        }
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

    function approveBurnProof(bytes32 proofHash) 
        external
        onlyRole(ROLE_APPROVER)
    {
        if (
            burnProofStorage[proofHash] != States.DefaultValue
        ) {
            revert CerbyBridgeV2_AlreadyApproved();
        }
        burnProofStorage[proofHash] = States.Approved;
        emit ApprovedBurnProof(proofHash);
    }

    function getReducedDestAmount(address srcToken, uint destAmount)
        private
        view
        returns(uint)
    {
        uint fee = chainIdToFee[block.chainid] > 0? chainIdToFee[block.chainid]: DEFAULT_FEE;
    }

    function mintWithBurnProof(
        address      _srcToken,
        bytes memory destToken,  
        bytes memory destCaller,
        uint8        destChainType,
        uint32       destChainId,
        bytes32      destBurnProofHash,
        uint256      destAmount,
        uint256      srcNonce
    ) external {
        if (
            destCaller.length != 40
        ) {
            revert CerbyBridgeV2_InvalidDestinationCallerLength();
        }
        if (
            destToken.length != 40
        ) {
            revert CerbyBridgeV2_InvalidDestinationTokenLength();
        }

        

        bytes memory srcCaller = genericAddress(msg.sender);
        bytes memory srcToken = genericAddress(_srcToken);

        {
            bytes32 allowanceHash = getAllowanceHash(
                ChainType(destChainType),
                destChainId,
                srcToken,
                destToken
            );

            if (
                allowances[allowanceHash] != Allowance.Allowed
            ) {
                revert CerbyBridgeV2_DirectionAllowanceWasNotFound();
            }
        }

        if (
            burnProofStorage[destBurnProofHash] != States.Approved
        ) {
            revert CerbyBridgeV2_ProofIsNotApprovedOrAlreadyExecuted();
        }

        bytes memory packed = abi.encodePacked(
            srcToken, destToken, 
            srcCaller, destCaller,
            destAmount,
            uint8(_srcChainType), uint32(block.chainid), // srcChainType, srcChainId
            destChainType, destChainId,
            srcNonce
        );


        if (
            packed.length != 230 // 230 = 40 + 40 + 40 + 40 + 32 + 1 + 2 + 1 + 2 + 32
        ) {
            revert CerbyBridgeV2_InvalidPackageLength();
        }

        bytes32 computedBurnProofHash = sha256(packed);

        if (
            computedBurnProofHash != destBurnProofHash
        ) {
            revert CerbyBridgeV2_ProvidedHashIsInvalid();
        }

        burnProofStorage[destBurnProofHash] = States.Executed;

        ICerbyTokenMinterBurner(_srcToken).mintHumanAddress(msg.sender, destAmount);

        {
            ChainType _destChainType = ChainType(destChainType);
            uint32 _destChainId = destChainId;
            emit ProofOfMint(
                srcToken,
                destToken,
                srcCaller,
                destCaller,
                destAmount,
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
        if (
            destCaller.length != 40
        ) {
            revert CerbyBridgeV2_InvalidDestinationCallerLength();
        }
        if (
            destToken.length != 40
        ) {
            revert CerbyBridgeV2_InvalidDestinationTokenLength();
        }

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

            if (
                allowances[allowanceHash] != Allowance.Allowed
            ) {
                revert CerbyBridgeV2_DirectionAllowanceWasNotFound();
            }
        }

        if (
            srcAmount > ICerbyTokenMinterBurner(_srcToken).balanceOf(msg.sender)
        ) {
            revert CerbyBridgeV2_AmountMustNotExceedAvailableBalance();
        }

        uint256 srcNonce = srcNonceByToken[_srcToken];

        bytes memory packed  = abi.encodePacked(
            srcToken, destToken, 
            srcCaller, destCaller,
            srcAmount,
            uint8(_srcChainType), uint32(block.chainid), // srcChainType, srcChainId
            destChainType, destChainId,
            srcNonce
        );

        if (
            packed.length != 230 // 230 = 40 + 40 + 40 + 40 + 32 + 1 + 2 + 1 + 2 + 32
        ) {
            revert CerbyBridgeV2_InvalidPackageLength();
        }

        bytes32 computedBurnProofHash = sha256(packed);

        burnProofStorage[computedBurnProofHash] = States.Burned;

        ICerbyTokenMinterBurner(_srcToken).burnHumanAddress(msg.sender, srcAmount);

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
