// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.11;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/ICerbyTokenMinterBurner.sol";
import "./interfaces/ICerbySwapV1.sol";

contract CerbyBridgeV2 is AccessControlEnumerable {
    event ProofOfBurn(
        bytes     srcToken,
        bytes     destToken,
        bytes     srcCaller,
        bytes     destCaller,
        uint   srcAmount,
        uint   srcNonce,
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
        uint   destAmount,
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

    ChainType _currentBridgeChainType;
    

    // it's common storage for all chains (evm, casper, solana etc)
    // also it can be splitted in two storages (src and dest)
    mapping(bytes32 => States) public burnProofStorage;
    mapping(address => uint32) public srcNonceByToken;
    mapping(bytes32 => Allowance) public allowances;

    mapping(uint => uint) public chainIdToFee;
    uint constant DEFAULT_FEE = 5e18; // 5 cerUSD fee
    address constant CER_USD_CONTRACT = address(0);
    address constant CERBY_SWAP_V1_CONTRACT = address(0);
    
    bytes32 public constant ROLE_APPROVER = keccak256("ROLE_APPROVER");
    address constant brideFeesBeneficiary = 0xdEF78a28c78A461598d948bc0c689ce88f812AD8;

    constructor() {
        _currentBridgeChainType = ChainType.Evm;     

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

    // 40 bytes
    function genericAddress(address some) private pure returns(bytes memory) {
        bytes memory result = new bytes(40);
        assembly {
            mstore(add(result, 40), some)
        }
        return result;
    }

    function getReducedDestAmount(address srcToken, uint destAmount)
        private
        view
        returns(uint)
    {
        uint fee = chainIdToFee[block.chainid] > 0? chainIdToFee[block.chainid]: DEFAULT_FEE;
        if (srcToken == CER_USD_CONTRACT) {
            destAmount -= fee;
        } else {
            destAmount -= ICerbySwapV1(CERBY_SWAP_V1_CONTRACT).getInputTokensForExactTokens(
                srcToken,
                CER_USD_CONTRACT,
                fee
            );
        }

        return destAmount;
    }  

    // TODO: setAllowancesBatch
    function setAllowance(
        address       srcToken,
        bytes memory  destToken,
        ChainType     destChainType,
        uint32        destChainId
    ) external {
        bytes32 allowanceHash = getAllowanceHash(
            genericAddress(srcToken),
            destToken,
            destChainType,
            destChainId
        );

        allowances[allowanceHash] = Allowance.Allowed;
    }

    function getAllowanceHash(
        bytes memory  srcGenericToken, // поменял порядок
        bytes memory  destGenericToken,
        ChainType     destChainType,
        uint32        destChainId
    ) 
        private 
        view 
        returns(bytes32) 
    {
        return sha256(abi.encodePacked(
            uint8(_currentBridgeChainType),
            uint32(block.chainid),
            uint8(destChainType),
            destChainId,
            srcToken,
            destToken
        ));
    }

    function checkAllowanceHash(
        bytes memory srcGenericToken,  // поменял порядок
        bytes memory destGenericToken,
        ChainType destChainType,
        uint32 destChainId
    )
        private
        view
    {
        bytes32 allowanceHash = getAllowanceHash(
            srcGenericToken,
            destGenericToken,
            destChainType,
            destChainId
        );

        if (
            allowances[allowanceHash] != Allowance.Allowed
        ) {
            revert CerbyBridgeV2_DirectionAllowanceWasNotFound();
        }
    }

    function generateSignature(
        bytes memory srcGenericToken,  // поменял порядок
        bytes memory srcGenericCaller, 
        uint8 srcChainType,
        uint32 srcChainId,
        uint srcNonce,
        bytes memory destGenericToken,
        bytes memory destGenericCaller,
        ChainType destChainType,
        uint32 destChainId,
        uint destAmount
    )
        private
        pure
        returns(bytes32)
    {
        bytes memory packed  = abi.encodePacked(
            srcGenericToken,  // поменял порядок
            srcGenericCaller,
            srcChainType,
            srcChainId,
            srcNonce,            
            destGenericToken, 
            destGenericCaller,
            destChainType, 
            destChainId,
            destAmount
        );

        if (
            packed.length != 230 // 230 = 40 + 40 + 40 + 40 + 32 + 1 + 2 + 1 + 2 + 32
        ) {
            revert CerbyBridgeV2_InvalidPackageLength();
        }

        bytes32 computedBurnProofHash = sha256(packed);
        return computedBurnProofHash;
    }
    
    function burnAndCreateProof(
        uint srcAmount, // поменял порядок
        address srcToken,
        bytes memory destGenericToken, 
        bytes memory destGenericCaller,
        ChainType destChainType,
        uint32 destChainId
    ) external {
        if (
            destGenericToken.length != 40
        ) {
            revert CerbyBridgeV2_InvalidDestinationCallerLength();
        }
        if (
            destGenericToken.length != 40
        ) {
            revert CerbyBridgeV2_InvalidDestinationTokenLength();
        }

        bytes memory srcGenericCaller = genericAddress(msg.sender);
        bytes memory srcGenericToken = genericAddress(srcToken);

        if (
            destChainType == _currentBridgeChainType &&
            (
                destGenericToken != srcGenericToken ||
                destGenericCaller != srcGenericCaller
            )
        ) {
            revert CerbyBridgeV2_TokenAndCallerMustBeEqualForEvmBridging();
        }

        checkAllowanceHash(
            srcGenericToken, 
            destGenericToken,
            destChainType,
            destChainId
        );

        uint srcNonce = srcNonceByToken[srcToken];
        uint destAmount = getReducedDestAmount(srcToken, srcAmount);

        bytes32 computedBurnProofHash = generateSignature(
            srcGenericToken, 
            srcGenericCaller, 
            uint8(_currentBridgeChainType),
            uint32(block.chainid),
            srcNonce,
            destGenericToken,
            destGenericCaller,
            destChainType,
            destChainId,
            destAmount
        );

        ICerbyTokenMinterBurner(srcToken).burnHumanAddress(msg.sender, srcAmount);
        ICerbyTokenMinterBurner(srcToken).mintHumanAddress(brideFeesBeneficiary, srcAmount - destAmount);

        emit ProofOfBurn(
            srcGenericToken,
            destGenericToken,
            srcGenericCaller,
            destGenericCaller,
            destAmount,
            srcNonce,
            _currentBridgeChainType,
            uint32(block.chainid),
            ChainType(destChainType),
            destChainId,
            computedBurnProofHash
        );

        srcNonceByToken[srcToken]++;

        // return computedBurnProofHash;
    }

    function mintWithBurnProof(
        bytes memory srcGenericToken, // поменял порядок
        bytes memory srcGenericCaller,
        uint8 srcChainType,
        uint32 srcChainId,
        bytes32 srcBurnProofHash,
        uint srcNonce,
        bytes memory destGenericToken,
        bytes memory destGenericCaller,
        uint destAmount
    ) external {
        if (
            srcChainType == _currentBridgeChainType &&
            (
                destGenericToken != srcGenericToken ||
                destGenericCaller != srcGenericCaller
            )
        ) {
            revert CerbyBridgeV2_TokenAndCallerMustBeEqualForEvmBridging();
        }

        checkAllowanceHash(
            destGenericToken,
            srcGenericToken, 
            srcChainType,
            srcChainId
        );

        if (
            burnProofStorage[destBurnProofHash] != States.Approved
        ) {
            revert CerbyBridgeV2_ProofIsNotApprovedOrAlreadyExecuted();
        }

        bytes32 computedBurnProofHash = generateSignature(
            srcGenericToken, 
            srcGenericCaller, 
            destGenericToken,
            destGenericCaller,
            destAmount,
            uint8(_currentBridgeChainType),
            uint32(block.chainid),
            uint8(ChainType(destChainType)),
            destChainId,
            srcNonce
        );
    function generateSignature(
        bytes memory srcGenericToken, 
        bytes memory srcGenericCaller, 
        uint8 srcChainType,
        uint32 srcChainId,
        uint srcNonce,
        bytes memory destGenericToken,
        bytes memory destGenericCaller,
        uint8 destChainType,
        uint32 destChainId,
        uint destAmount
    )

        if (
            computedBurnProofHash != destBurnProofHash
        ) {
            revert CerbyBridgeV2_ProvidedHashIsInvalid();
        }

        burnProofStorage[destBurnProofHash] = States.Executed;

        ICerbyTokenMinterBurner(_srcToken).mintHumanAddress(msg.sender, destAmount);

        emit ProofOfMint(
            srcGenericToken,
            destGenericToken,
            srcGenericCaller,
            destGenericCaller,
            destAmount,
            _currentBridgeChainType,
            uint32(block.chainid),
            ChainType(destChainType),
            uint32(destChainId),
            computedBurnProofHash
        );
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
}
