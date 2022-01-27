// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.11;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/ICerbyTokenMinterBurner.sol";
import "./interfaces/ICerbySwapV1.sol";

contract CerbyBridgeV2 is AccessControlEnumerable {

    struct Proof {
        bytes32 srcBurnProofHash;
        bytes srcGenericToken;
        bytes srcGenericCaller;
        uint8 srcChainType;
        uint32 srcChainId;
        uint64 srcNonce;
        bytes destGenericToken;
        bytes destGenericCaller;
        uint8 destChainType;
        uint32 destChainId;
        uint256 destAmount;
    }

    event ProofOfBurnOrMint(
        bool isBurn,  // поменял порядок
        Proof proof
    );

    event ApprovedBurnProofHash(bytes32 srcBurnProofHash);

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
    error CerbyBridgeV2_InvalidGenericTokenLength();
    error CerbyBridgeV2_InvalidGenericCallerLength();
    error CerbyBridgeV2_AlreadyApproved();
    error CerbyBridgeV2_ProofIsNotApprovedOrAlreadyExecuted();
    error CerbyBridgeV2_ProvidedHashIsInvalid();
    error CerbyBridgeV2_TokenAndCallerMustBeEqualForEvmBridging();
    error CerbyBridgeV2_AmountIsLessThanBridgeFees();

    uint8 _currentBridgeChainType;
    uint32 _currentBridgeChainId;
    

    // it's common storage for all chains (evm, casper, solana etc)
    // also it can be splitted in two storages (src and dest)
    mapping(bytes32 => States) public burnProofStorage;
    mapping(address => uint32) public srcNonceByToken;
    mapping(bytes32 => Allowance) public allowances;

    mapping(uint256 => uint) public chainIdToFee;
    uint256 constant DEFAULT_FEE = 5e18; // 5 cerUSD fee
    address constant CER_USD_CONTRACT = address(0);
    address constant CERBY_SWAP_V1_CONTRACT = address(0);
    
    bytes32 public constant ROLE_APPROVER = keccak256("ROLE_APPROVER");
    address constant bridgeFeesBeneficiary = 0xdEF78a28c78A461598d948bc0c689ce88f812AD8;

    constructor() {
        _setupRole(ROLE_APPROVER, msg.sender);
        _setupRole(ROLE_APPROVER, bridgeFeesBeneficiary);

        _currentBridgeChainType = uint8(ChainType.Evm);
        _currentBridgeChainId = uint32(block.chainid);

        chainIdToFee[1] = 50e18; // 50 cerUSD to ethereum   
    }

    // 40 bytes
    function getGenericAddress(address addr) 
        private 
        pure 
        returns(bytes memory) 
    {
        bytes memory result = new bytes(40);
        assembly {
            mstore(add(result, 40), addr)
        }
        return result;
    }

    function getReducedDestAmount(address srcToken, uint256 destAmount, uint256 destChainId)
        private
        view
        returns(uint)
    {
        uint256 feeInCerUsd = 
            chainIdToFee[destChainId] > 0? 
                chainIdToFee[destChainId]: 
                DEFAULT_FEE;
        srcToken; // TODO: to silent warning remove on production

        // if srcToken == CER_USD_CONTRACT then we substract fee directly from destAmount
        uint256 substractAmountInTokens = feeInCerUsd;
        /*
        // TODO: uncomment code below in production
        if (srcToken != CER_USD_CONTRACT) {
            substractAmountInTokens = 
                ICerbySwapV1(CERBY_SWAP_V1_CONTRACT).getInputTokensForExactTokens(
                    srcToken,
                    CER_USD_CONTRACT,
                    feeInCerUsd
                );
        }*/

        if (
            destAmount <= substractAmountInTokens
        ) {
            revert CerbyBridgeV2_AmountIsLessThanBridgeFees();
        }

        return destAmount - substractAmountInTokens;
    }  

    function setAllowancesBulk(
        Proof[] memory proofs
    ) external {
        uint256 proofsLength = proofs.length;

        for (uint256 i; i<proofsLength; i++) {

            bytes32 allowanceHash = getAllowanceHashCurrent2Dest(
                proofs[i]
            );

            allowances[allowanceHash] = Allowance.Allowed;
        }
    }

    function getAllowanceHashCurrent2Dest(
        Proof memory proof
    ) 
        public 
        view 
        returns(bytes32) 
    {
        return sha256(abi.encodePacked(
            proof.srcGenericToken,
            _currentBridgeChainType,
            _currentBridgeChainId,
            proof.destGenericToken,
            proof.destChainType,
            proof.destChainId
        ));
    }

    function getAllowanceHashSrc2Dest(
        Proof memory proof
    ) 
        private 
        pure 
        returns(bytes32) 
    {
        return sha256(abi.encodePacked(
            proof.srcGenericToken, // поменял порядок
            proof.srcChainType,
            proof.srcChainId,
            proof.destGenericToken,
            proof.destChainType,
            proof.destChainId
        ));
    }

    function getAllowanceHashDest2Src(
        Proof memory proof
    ) 
        private 
        pure 
        returns(bytes32) 
    {
        return sha256(abi.encodePacked(
            proof.destGenericToken,
            proof.destChainType,
            proof.destChainId,
            proof.srcGenericToken,
            proof.srcChainType,
            proof.srcChainId
        ));
    }

    function checkAllowanceHashSrc2Dest(
        Proof memory proof
    )
        private
        view
    {
        bytes32 allowanceHash = getAllowanceHashSrc2Dest(proof);

        if (
            allowances[allowanceHash] != Allowance.Allowed
        ) {
            revert CerbyBridgeV2_DirectionAllowanceWasNotFound();
        }
    }

    function checkAllowanceHashDest2Src(
        Proof memory proof
    )
        private
        view
    {
        bytes32 allowanceHash = getAllowanceHashDest2Src(proof);

        if (
            allowances[allowanceHash] != Allowance.Allowed
        ) {
            revert CerbyBridgeV2_DirectionAllowanceWasNotFound();
        }
    }

    function computeBurnHash(
        Proof memory proof
    )
        private
        pure
        returns(bytes32)
    {
        bytes memory packed  = abi.encodePacked(
            proof.srcGenericToken,  // поменял порядок
            proof.srcGenericCaller,
            proof.srcChainType,
            proof.srcChainId,
            proof.srcNonce,            
            proof.destGenericToken, 
            proof.destGenericCaller,
            proof.destChainType,
            proof.destChainId,
            proof.destAmount
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
        uint256 srcAmount, // поменял порядок
        address srcToken,
        bytes memory destGenericToken, 
        bytes memory destGenericCaller,
        uint8 destChainType,
        uint32 destChainId
    ) external {
        if (
            destGenericToken.length != 40
        ) {
            revert CerbyBridgeV2_InvalidGenericCallerLength();
        }
        if (
            destGenericToken.length != 40
        ) {
            revert CerbyBridgeV2_InvalidGenericTokenLength();
        }

        // creating proof object from current chain to dest
        Proof memory proof = Proof(
            "",                                                     // srcBurnProofHash;
            getGenericAddress(srcToken),                            // srcGenericToken;
            getGenericAddress(msg.sender),                          // srcGenericCaller;
            _currentBridgeChainType,                                // srcChainType;
            _currentBridgeChainId,                                  // srcChainId;
            uint64(srcNonceByToken[srcToken]),                      // srcNonce;
            destGenericToken,                                       // destGenericToken;
            destGenericCaller,                                      // destGenericCaller;
            destChainType,                                          // destChainType;
            destChainId,                                            // destChainId;
            getReducedDestAmount(srcToken, srcAmount, destChainId)  // destAmount;
        );

        // EVM --> EVM bridge is allowed only for the same wallet
        if (
            _currentBridgeChainType == destChainType &&
            bytesEquals(proof.srcGenericCaller, destGenericCaller)
        ) {
            revert CerbyBridgeV2_TokenAndCallerMustBeEqualForEvmBridging();
        }

        // checking src --> dest allowance
        checkAllowanceHashSrc2Dest(proof);

        // generating src burn hash
        proof.srcBurnProofHash = computeBurnHash(proof);

        // burning amount user requested
        ICerbyTokenMinterBurner(srcToken).burnHumanAddress(msg.sender, srcAmount);

        // minting bridge fees
        ICerbyTokenMinterBurner(srcToken).mintHumanAddress(
            bridgeFeesBeneficiary, 
            srcAmount - proof.destAmount
        );

        emit ProofOfBurnOrMint(
            true,   // isBurn
            proof   // proof
        );

        // increasing nonce, to produce new hash even if sent data was the same
        srcNonceByToken[srcToken]++;
    }

    function mintWithBurnProof(
        bytes memory srcGenericToken, // поменял порядок
        bytes memory srcGenericCaller,
        uint8 srcChainType,
        uint32 srcChainId,
        bytes32 srcBurnProofHash,
        uint64 srcNonce,
        address destToken,
        uint256 destAmount
    ) 
        external 
    {
        if (
            srcGenericToken.length != 40
        ) {
            revert CerbyBridgeV2_InvalidGenericCallerLength();
        }
        if (
            srcGenericCaller.length != 40
        ) {
            revert CerbyBridgeV2_InvalidGenericTokenLength();
        }

        // creating proof object from src to current chain
        Proof memory proof = Proof(
            srcBurnProofHash,                   // srcBurnProofHash;
            srcGenericToken,                    // srcGenericToken;
            srcGenericCaller,                   // srcGenericCaller;
            srcChainType,                       // srcChainType;
            srcChainId,                         // srcChainId;
            srcNonce,                           // srcNonce;
            getGenericAddress(destToken),       // destGenericToken;
            getGenericAddress(msg.sender),      // destGenericCaller;
            _currentBridgeChainType,            // destChainType;
            _currentBridgeChainId,              // destChainId;
            destAmount                          // destAmount;
        );

        // EVM --> EVM bridge is allowed only for the same wallet
        if (
            srcChainType == _currentBridgeChainType &&
            bytesEquals(srcGenericCaller, proof.destGenericCaller)
        ) {
            revert CerbyBridgeV2_TokenAndCallerMustBeEqualForEvmBridging();
        }
        
        // checking opposite direction allowance
        // if current chain (dest) --> src allowed then src --> current chain (dest) is allowed as well
        checkAllowanceHashDest2Src(proof);

        if (
            burnProofStorage[srcBurnProofHash] != States.Approved
        ) {
            revert CerbyBridgeV2_ProofIsNotApprovedOrAlreadyExecuted();
        }

        // generating src burn hash
        bytes32 srcBurnProofHashComputed = computeBurnHash(proof);

        // making sure burn hash is valid
        if (
            srcBurnProofHash != srcBurnProofHashComputed
        ) {
            revert CerbyBridgeV2_ProvidedHashIsInvalid();
        }

        // updating hash in storage to make sure tokens are minted only once
        burnProofStorage[srcBurnProofHashComputed] = States.Executed;

        // minting the tokens to the current wallet
        ICerbyTokenMinterBurner(destToken).mintHumanAddress(msg.sender, destAmount);

        emit ProofOfBurnOrMint(
            false,  // isBurn
            proof   // proof
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
        emit ApprovedBurnProofHash(proofHash);
    }

    function setChainsToFee(uint[] calldata chainIdsTo, uint256 fee)
        public
        onlyRole(ROLE_ADMIN)
    {
        uint256 chainIdsToLength = chainIdsTo.length;
        for(uint256 i; i<chainIdsToLength; i++) {
            chainIdToFee[chainIdsTo[i]] = fee;
        }
    }  


    // Checks if two `bytes memory` variables are equal. This is done using hashing,
    // which is much more gas efficient then comparing each byte individually.
    // Equality means that:
    //  - 'self.length == other.length'
    //  - For 'n' in '[0, self.length)', 'self[n] == other[n]'
    function bytesEquals(bytes memory self, bytes memory other) internal pure returns (bool equal) {
        if (self.length != other.length) {
            return false;
        }
        uint256 addr;
        uint256 addr2;
        assembly {
            addr := add(self, /*BYTES_HEADER_SIZE*/32)
            addr2 := add(other, /*BYTES_HEADER_SIZE*/32)
        }
        equal = memoryEquals(addr, addr2, self.length);
    }

    // Compares the 'len' bytes starting at address 'addr' in memory with the 'len'
    // bytes starting at 'addr2'.
    // Returns 'true' if the bytes are the same, otherwise 'false'.
    function memoryEquals(uint256 addr, uint256 addr2, uint256 len) internal pure returns (bool equal) {
        assembly {
            equal := eq(keccak256(addr, len), keccak256(addr2, len))
        }
    }
}
