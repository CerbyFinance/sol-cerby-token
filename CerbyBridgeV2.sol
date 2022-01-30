// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.11;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/ICerbyTokenMinterBurner.sol";
import "./interfaces/ICerbySwapV1.sol";

contract CerbyBridgeV2 is AccessControlEnumerable {
    struct Proof {
        bytes32 burnProofHash;
        bytes burnGenericCaller;
        uint64 burnNonce;
        bytes mintGenericCaller;
        uint256 mintAmount;
        Allowance allowance;
    }

    struct Allowance {
        bytes burnGenericToken;
        uint8 burnChainType;
        uint32 burnChainId;
        bytes mintGenericToken;
        uint8 mintChainType;
        uint32 mintChainId;
    }

    event ProofOfBurnOrMint(
        bool isBurn, // поменял порядок
        Proof proof
    );

    event ApprovedBurnProofHash(bytes32 burnProofHash);

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

    enum AllowanceStatus {
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
    // also it can be splitted in two storages (burn and mint)
    mapping(bytes32 => States) public burnProofStorage;
    mapping(address => uint32) public burnNonceByToken;
    mapping(bytes32 => AllowanceStatus) public allowances;

    mapping(bytes32 => uint256) public chainToFee;
    uint256 constant DEFAULT_FEE = 5e18; // 5 cerUSD fee
    address constant CER_USD_CONTRACT = address(0);
    address constant CERBY_SWAP_V1_CONTRACT = address(0);

    bytes32 public constant ROLE_APPROVER = keccak256("ROLE_APPROVER");
    address constant bridgeFeesBeneficiary =
        0xdEF78a28c78A461598d948bc0c689ce88f812AD8;
    bytes4 constant HASH_SEPARATOR = 0xc0de0001;

    constructor() {
        _setupRole(ROLE_APPROVER, msg.sender);
        _setupRole(ROLE_APPROVER, bridgeFeesBeneficiary);

        _currentBridgeChainType = uint8(ChainType.Evm);
        _currentBridgeChainId = uint32(block.chainid);

        bytes32 ethereumChainHash = getChainHash(_currentBridgeChainType, 1);
        chainToFee[ethereumChainHash] = 50e18; // 50 cerUSD to ethereum, 5 cerUSD for other chains
    }

    // 40 bytes
    function getGenericAddress(address addr)
        private
        pure
        returns (bytes memory)
    {
        bytes memory result = new bytes(40);
        assembly {
            mstore(add(result, 40), addr)
        }
        return result;
    }

    function getReducedMintAmount(
        address burnToken,
        uint256 mintAmount,
        uint8 mintChainType,
        uint32 mintChainId
    ) private view returns (uint256) {
        bytes32 chainHash = getChainHash(mintChainType, mintChainId);
        uint256 chainFee = chainToFee[chainHash];
        uint256 feeInCerUsd = chainFee > 0 ? chainFee : DEFAULT_FEE;
        burnToken; // TODO: to silent warning remove on production

        // if burnToken == CER_USD_CONTRACT then we substract fee directly from mintAmount
        uint256 substractAmountInTokens = feeInCerUsd;
        /*
        // TODO: uncomment code below in production
        if (burnToken != CER_USD_CONTRACT) {
            substractAmountInTokens = 
                ICerbySwapV1(CERBY_SWAP_V1_CONTRACT).getInputTokensForExactTokens(
                    burnToken,
                    CER_USD_CONTRACT,
                    feeInCerUsd
                );
        }*/

        if (mintAmount <= substractAmountInTokens) {
            revert CerbyBridgeV2_AmountIsLessThanBridgeFees();
        }

        return mintAmount - substractAmountInTokens;
    }

    function setAllowancesBulk(Allowance[] memory _allowances, AllowanceStatus _status)
        external
        onlyRole(ROLE_ADMIN)
    {
        uint256 allowancesLength = _allowances.length;

        for (uint256 i; i < allowancesLength; i++) {
            if (
                _currentBridgeChainType == _allowances[i].mintChainType &&
                _currentBridgeChainId == _allowances[i].mintChainId
            ) {
                continue;
            }

            bytes32 allowanceHash = getAllowanceHashCurrent2Mint(_allowances[i]);

            if (allowances[allowanceHash] != _status) {
                allowances[allowanceHash] = _status;
            }
        }
    }

    function getAllowanceHashCurrent2Mint(Allowance memory _allowance)
        private
        view
        returns (bytes32)
    {
        return
            sha256(
                abi.encodePacked(
                    _allowance.burnGenericToken,
                    _currentBridgeChainType,
                    _currentBridgeChainId,
                    _allowance.mintGenericToken,
                    _allowance.mintChainType,
                    _allowance.mintChainId
                )
            );
    }

    function getAllowanceHashBurn2Mint(Allowance memory _allowance)
        private
        pure
        returns (bytes32)
    {
        return
            sha256(
                abi.encodePacked(
                    _allowance.burnGenericToken, // поменял порядок
                    _allowance.burnChainType,
                    _allowance.burnChainId,
                    _allowance.mintGenericToken,
                    _allowance.mintChainType,
                    _allowance.mintChainId
                )
            );
    }

    function getAllowanceHashMint2Burn(Allowance memory _allowance)
        public
        pure
        returns (bytes32)
    {
        return
            sha256(
                abi.encodePacked(
                    _allowance.mintGenericToken,
                    _allowance.mintChainType,
                    _allowance.mintChainId,
                    _allowance.burnGenericToken,
                    _allowance.burnChainType,
                    _allowance.burnChainId
                )
            );
    }

    function checkAllowanceHashBurn2Mint(Allowance memory _allowance) private view {
        bytes32 allowanceHash = getAllowanceHashBurn2Mint(_allowance);

        if (allowances[allowanceHash] != AllowanceStatus.Allowed) {
            revert CerbyBridgeV2_DirectionAllowanceWasNotFound();
        }
    }

    function checkAllowanceHashMint2Burn(Allowance memory _allowance) private view {
        bytes32 allowanceHash = getAllowanceHashMint2Burn(_allowance);

        if (allowances[allowanceHash] != AllowanceStatus.Allowed) {
            revert CerbyBridgeV2_DirectionAllowanceWasNotFound();
        }
    }

    function computeBurnHash(Proof memory proof)
        private
        pure
        returns (bytes32)
    {
        bytes memory packed = abi.encodePacked(
            proof.allowance.burnGenericToken, // 40 = bytes40
            proof.burnGenericCaller, // 40 = bytes40
            proof.allowance.burnChainType, // 1 = uint8
            proof.allowance.burnChainId, // 4 = uint32
            proof.burnNonce, // 8 = uint64
            HASH_SEPARATOR, // 4 = bytes4
            proof.allowance.mintGenericToken, // 40 = bytes40
            proof.mintGenericCaller, // 40 = bytes40
            proof.allowance.mintChainType, // 1 = uint8
            proof.allowance.mintChainId, // 4 = uint32
            proof.mintAmount // 32 = uint256
        );

        if (
            packed.length != 214 // 214 = 40 + 40 + 1 + 4 + 8 + 4 + 40 + 40 + 1 + 4 + 32
        ) {
            revert CerbyBridgeV2_InvalidPackageLength();
        }

        bytes32 computedBurnProofHash = sha256(packed);
        return computedBurnProofHash;
    }

    function burnAndCreateProof(
        uint256 burnAmount, // поменял порядок
        address burnToken,
        bytes memory mintGenericToken,
        bytes memory mintGenericCaller,
        uint8 mintChainType,
        uint32 mintChainId
    ) external {
        if (mintGenericToken.length != 40) {
            revert CerbyBridgeV2_InvalidGenericCallerLength();
        }
        if (mintGenericToken.length != 40) {
            revert CerbyBridgeV2_InvalidGenericTokenLength();
        }

        // creating allowance object from current chain to mint
        Allowance memory allowance = Allowance(
            getGenericAddress(burnToken), // burnGenericToken;
            _currentBridgeChainType, // burnChainType;
            _currentBridgeChainId, // burnChainId;
            mintGenericToken, // mintGenericToken;
            mintChainType, // mintChainType;
            mintChainId // mintChainId;
        );

        // creating proof object from current chain to mint
        Proof memory proof = Proof(
            "", // burnProofHash;
            getGenericAddress(msg.sender), // burnGenericCaller;
            uint64(burnNonceByToken[burnToken]), // burnNonce;
            mintGenericCaller, // mintGenericCaller;
            getReducedMintAmount(
                burnToken,
                burnAmount,
                mintChainType,
                mintChainId
            ), // mintAmount;
            allowance // allowance
        );

        // EVM --> EVM bridge is allowed only for the same wallet
        if (
            _currentBridgeChainType == mintChainType &&
            sha256(proof.burnGenericCaller) == sha256(mintGenericCaller)
        ) {
            revert CerbyBridgeV2_TokenAndCallerMustBeEqualForEvmBridging();
        }

        // checking burn --> mint allowance
        checkAllowanceHashBurn2Mint(allowance);

        // generating burn burn hash
        proof.burnProofHash = computeBurnHash(proof);

        // burning amount user requested
        ICerbyTokenMinterBurner(burnToken).burnHumanAddress(
            msg.sender,
            burnAmount
        );

        // minting bridge fees
        ICerbyTokenMinterBurner(burnToken).mintHumanAddress(
            bridgeFeesBeneficiary,
            burnAmount - proof.mintAmount
        );

        emit ProofOfBurnOrMint(
            true, // isBurn
            proof // proof
        );

        // increasing nonce, to produce new hash even if sent data was the same
        burnNonceByToken[burnToken]++;
    }

    function mintWithBurnProof(
        bytes memory burnGenericToken, // поменял порядок
        bytes memory burnGenericCaller,
        uint8 burnChainType,
        uint32 burnChainId,
        bytes32 burnProofHash,
        uint64 burnNonce,
        address mintToken,
        uint256 mintAmount
    ) external {
        if (burnGenericToken.length != 40) {
            revert CerbyBridgeV2_InvalidGenericCallerLength();
        }
        if (burnGenericCaller.length != 40) {
            revert CerbyBridgeV2_InvalidGenericTokenLength();
        }

        // creating allowance object from current chain to mint
        Allowance memory allowance = Allowance(
            burnGenericToken, // burnGenericToken;
            burnChainType, // burnChainType;
            burnChainId, // burnChainId;
            getGenericAddress(mintToken), // mintGenericToken;
            _currentBridgeChainType, // mintChainType;
            _currentBridgeChainId // mintChainId;
        );

        // creating proof object from burn to current chain
        Proof memory proof = Proof(
            burnProofHash, // burnProofHash;
            burnGenericCaller, // burnGenericCaller;
            burnNonce, // burnNonce;
            getGenericAddress(msg.sender), // mintGenericCaller;
            mintAmount, // mintAmount;
            allowance // allowance
        );

        // EVM --> EVM bridge is allowed only for the same wallet
        if (
            burnChainType == _currentBridgeChainType &&
            sha256(burnGenericCaller) == sha256(proof.mintGenericCaller)
        ) {
            revert CerbyBridgeV2_TokenAndCallerMustBeEqualForEvmBridging();
        }

        // checking opposite direction allowance
        // if current chain (mint) --> burn allowed then burn --> current chain (mint) is allowed as well
        checkAllowanceHashMint2Burn(allowance);

        if (burnProofStorage[burnProofHash] != States.Approved) {
            revert CerbyBridgeV2_ProofIsNotApprovedOrAlreadyExecuted();
        }

        // generating burn burn hash
        bytes32 burnProofHashComputed = computeBurnHash(proof);

        // making sure burn hash is valid
        if (burnProofHash != burnProofHashComputed) {
            revert CerbyBridgeV2_ProvidedHashIsInvalid();
        }

        // updating hash in storage to make sure tokens are minted only once
        burnProofStorage[burnProofHashComputed] = States.Executed;

        // minting the tokens to the current wallet
        ICerbyTokenMinterBurner(mintToken).mintHumanAddress(
            msg.sender,
            mintAmount
        );

        emit ProofOfBurnOrMint(
            false, // isBurn
            proof // proof
        );
    }

    function approveBurnProof(bytes32 proofHash)
        external
        onlyRole(ROLE_APPROVER)
    {
        if (burnProofStorage[proofHash] != States.DefaultValue) {
            revert CerbyBridgeV2_AlreadyApproved();
        }

        burnProofStorage[proofHash] = States.Approved;
        emit ApprovedBurnProofHash(proofHash);
    }

    function getChainHash(uint8 chainType, uint32 chainId)
        public
        pure
        returns (bytes32)
    {
        return sha256(abi.encodePacked(chainType, chainId));
    }

    function setChainsToFee(bytes32[] calldata chainsTo, uint256 fee)
        public
        onlyRole(ROLE_ADMIN)
    {
        uint256 chainsToLength = chainsTo.length;
        for (uint256 i; i < chainsToLength; i++) {
            chainToFee[chainsTo[i]] = fee;
        }
    }
}
