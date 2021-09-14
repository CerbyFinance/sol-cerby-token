// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/IDeftStorageContract.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";

struct DirectionSettings {
    bool isAllowedDirection;
    uint amountAsFee;
}

contract CrossChainBridge is AccessControlEnumerable {
    event ProofOfBurn(address addr, address token, uint amount, uint amountAsFee, uint currentNonce, uint sourceChain, uint destinationChain, bytes32 transactionHash);
    event ProofOfMint(address addr, address token, uint amountAsFee, uint finalAmount, bytes32 transactionHash);
    event ApprovedTransaction(bytes32 transactionHash);
    event BulkApprovedTransactions(bytes32[] transactionHashes);
    event FeeUpdated(uint newFeePercent);
    
    enum States{ DefaultValue, Burned, Approved, Executed }
    mapping(bytes32 => States) public transactionStorage;
    
    uint constant NO_BOTS_TECH_CONTRACT_ID = 0;
    uint constant DEFT_STORAGE_CONTRACT_ID = 3;
    bytes32 public constant ROLE_APPROVER = keccak256("ROLE_APPROVER");
    
    
    address UNISWAP_V2_FACTORY_ADDRESS;
    address WETH_TOKEN_ADDRESS;
    
    mapping(address => uint) public currentNonce;
    address public beneficiaryAddress;
    
    mapping(address => mapping (uint => DirectionSettings)) public directionSettings;
    
    uint constant ETH_MAINNET_CHAIN_ID = 1;
    uint constant ETH_ROPSTEN_CHAIN_ID = 3;
    uint constant ETH_KOVAN_CHAIN_ID = 42;
    uint constant BSC_MAINNET_CHAIN_ID = 56;
    uint constant BSC_TESTNET_CHAIN_ID = 97;
    uint constant MATIC_MAINNET_CHAIN_ID = 137;
    
    address constant APPROVER_WALLET = 0xdEF78a28c78A461598d948bc0c689ce88f812AD8;
    
    struct SourceProofOfBurn {
        uint amountToBridge;
        uint amountAsFee;
        uint sourceChainId;
        uint sourceNonce;
        address sourceTokenAddr;
        bytes32 transactionHash;
    }
    
    constructor() {
        _setupRole(ROLE_ADMIN, msg.sender);
        _setupRole(ROLE_APPROVER, msg.sender);
        _setupRole(ROLE_APPROVER, APPROVER_WALLET);
        
        //_setupRole(ROLE_ADMIN, 0x539FaA851D86781009EC30dF437D794bCd090c8F);
        //_setupRole(ROLE_APPROVER, 0x539FaA851D86781009EC30dF437D794bCd090c8F);
        
        beneficiaryAddress = APPROVER_WALLET;
        
        
        /* Testnet */
        if (block.chainid == ETH_KOVAN_CHAIN_ID)
        {
            directionSettings[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840][BSC_TESTNET_CHAIN_ID] = DirectionSettings(true, 1e23); // allow to bridge to bsc
        } else if (block.chainid == BSC_TESTNET_CHAIN_ID)
        {
            directionSettings[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840][ETH_KOVAN_CHAIN_ID] = DirectionSettings(true, 15e23); // allow to bridge to eth
        }
        
        /* MAINNET */
        if (block.chainid == ETH_MAINNET_CHAIN_ID)
        {
            directionSettings[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840][BSC_MAINNET_CHAIN_ID] = DirectionSettings(true, 1e23); // allow to bridge to bsc
            directionSettings[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840][MATIC_MAINNET_CHAIN_ID] = DirectionSettings(true, 1e23); // allow to bridge to polygon
        } else if (block.chainid == BSC_MAINNET_CHAIN_ID)
        {
            directionSettings[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840][ETH_MAINNET_CHAIN_ID] = DirectionSettings(true, 15e23); // allow to bridge to eth
            directionSettings[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840][MATIC_MAINNET_CHAIN_ID] = DirectionSettings(true, 1e23); // allow to bridge to polygon
        } else if (block.chainid == MATIC_MAINNET_CHAIN_ID)
        {
            directionSettings[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840][ETH_MAINNET_CHAIN_ID] = DirectionSettings(true, 15e23); // allow to bridge to eth
            directionSettings[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840][BSC_MAINNET_CHAIN_ID] = DirectionSettings(true, 1e23); // allow to bridge to bsc
        }
    }
    
    
    function updateDirectionSettings(address token, uint chainId, DirectionSettings calldata _directionSettings)
        external
        onlyRole(ROLE_ADMIN)
    {
        directionSettings[token][chainId] = _directionSettings;
    }
    
    function updateBeneficiaryAddress(address newBeneficiaryAddr)
        external
        onlyRole(ROLE_ADMIN)
    {
        beneficiaryAddress = newBeneficiaryAddr;
    }
    
    function markTransactionAsApproved(bytes32 transactionHash) 
        external
        onlyRole(ROLE_APPROVER)
    {
        require(
            transactionStorage[transactionHash] < States.Approved,
            "CCB: Already approved"
        );
        transactionStorage[transactionHash] = States.Approved;
        emit ApprovedTransaction(transactionHash);
    }
    
    function bulkMarkTransactionsAsApproved(bytes32[] memory transactionHashes) 
        external
        onlyRole(ROLE_APPROVER)
    {
        for(uint i=0; i<transactionHashes.length; i++)
        {
            if (transactionStorage[transactionHashes[i]] < States.Approved)
            {
                transactionStorage[transactionHashes[i]] = States.Approved;
            } else
            {
                transactionHashes[i] = 0x0;
            }
        }
        emit BulkApprovedTransactions(transactionHashes);
    }
    
    function mintWithBurnProof(SourceProofOfBurn memory sourceProofOfBurn) 
        external
    {
        require(
            transactionStorage[sourceProofOfBurn.transactionHash] == States.Approved,
            "CCB: Transaction is not approved or already executed"
        );
        
        bytes32 transactionHash = keccak256(abi.encodePacked(
                msg.sender, sourceProofOfBurn.sourceTokenAddr, sourceProofOfBurn.amountToBridge, sourceProofOfBurn.amountAsFee, sourceProofOfBurn.sourceChainId, block.chainid, sourceProofOfBurn.sourceNonce
            ));
        require(
            transactionHash == sourceProofOfBurn.transactionHash,
            "CCB: Provided hash is invalid"
        );
        
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(sourceProofOfBurn.sourceTokenAddr);
        IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
            iDefiFactoryToken.getUtilsContractAtPos(DEFT_STORAGE_CONTRACT_ID)
        );
        require(
            !iDeftStorageContract.isBotAddress(msg.sender),
            "CCB: Minting is temporary disabled!"
        );
        
        transactionStorage[sourceProofOfBurn.transactionHash] = States.Executed;
        
        uint amountAsFee = sourceProofOfBurn.amountAsFee;
        uint finalAmount = sourceProofOfBurn.amountToBridge - amountAsFee; 
        
        iDefiFactoryToken.mintByBridge(msg.sender, finalAmount);
        iDefiFactoryToken.mintByBridge(beneficiaryAddress, amountAsFee);
        
        emit ProofOfMint(msg.sender, sourceProofOfBurn.sourceTokenAddr, amountAsFee, finalAmount, transactionHash);
    }
    
    function burnAndCreateProof(address token, uint amount, uint destinationChainId) 
        external
    {
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(token);
        require(
            amount <= iDefiFactoryToken.balanceOf(msg.sender),
            "CCB: Amount must not exceed available balance. Try reducing the amount."
        );
        require(
            block.chainid != destinationChainId,
            "CCB: Destination chain must be different from current chain"
        );
        require(
            directionSettings[token][destinationChainId].isAllowedDirection,
            "CCB: Destination chain is not allowed"
        );
        
        require(
            amount > directionSettings[token][destinationChainId].amountAsFee,
            "CCB: Amount is lower than the minimum permitted amount"
        );
        
        IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
            iDefiFactoryToken.getUtilsContractAtPos(DEFT_STORAGE_CONTRACT_ID)
        );
        require(
            !iDeftStorageContract.isBotAddress(msg.sender),
            "CCB: Burning is temporary disabled!"
        );
        
        bytes32 transactionHash = keccak256(abi.encodePacked(
                msg.sender, token, amount, directionSettings[token][destinationChainId].amountAsFee, block.chainid, destinationChainId, currentNonce[token]
            ));
            
        transactionStorage[transactionHash] = States.Burned;
        
        iDefiFactoryToken.burnByBridge(msg.sender, amount);
        
        emit ProofOfBurn(msg.sender, token, amount, directionSettings[token][destinationChainId].amountAsFee, currentNonce[token], block.chainid, destinationChainId, transactionHash);
        currentNonce[token]++;
    }
}