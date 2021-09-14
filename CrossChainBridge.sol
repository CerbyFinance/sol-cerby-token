// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./openzeppelin/utils/structs/EnumerableSet.sol";
import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/IDeftStorageContract.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";

contract CrossChainBridge is AccessControlEnumerable {
    event ProofOfBurn(address addr, address token, uint amount, uint currentNonce, uint sourceChain, uint destinationChain, bytes32 transactionHash);
    event ProofOfMint(address addr, address token, uint amountAsFee, uint finalAmount, bytes32 transactionHash);
    event ApprovedTransaction(bytes32 transactionHash);
    event BulkApprovedTransactions(bytes32[] transactionHashes);
    event FeeUpdated(uint newFeePercent);
    
    enum States{ DefaultValue, Burned, Approved, Executed }
    mapping(bytes32 => States) public transactionStorage;
    
    uint public maxGweiSupported = 50e9;
    
    uint constant NO_BOTS_TECH_CONTRACT_ID = 0;
    uint constant DEFT_STORAGE_CONTRACT_ID = 3;
    bytes32 public constant ROLE_APPROVER = keccak256("ROLE_APPROVER");
    
    uint lastGasPrice = 100e9;
    uint constant GAS_PER_APPROVE = 100e3;
    
    
    address UNISWAP_V2_FACTORY_ADDRESS;
    address WETH_TOKEN_ADDRESS;
    
    mapping(address => uint) public currentNonce;
    address public beneficiaryAddress;
    
    mapping(address => mapping (uint => bool)) public isAllowedToBridgeToChainId;
    
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private allowedContracts;
    
    uint constant ETH_MAINNET_CHAIN_ID = 1;
    uint constant ETH_ROPSTEN_CHAIN_ID = 3;
    uint constant ETH_KOVAN_CHAIN_ID = 42;
    uint constant BSC_MAINNET_CHAIN_ID = 56;
    uint constant BSC_TESTNET_CHAIN_ID = 97;
    uint constant MATIC_MAINNET_CHAIN_ID = 137;
    
    address constant APPROVER_WALLET = 0xdEF78a28c78A461598d948bc0c689ce88f812AD8;
    
    struct SourceProofOfBurn {
        uint amount;
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
        
        /*address tokenAddr1 = 0x5564217Dd1e1255eA751C9C506Fac9eD25FA5240;
        address tokenAddr2 = 0x60b6F75D513E3C60bd325AE6B64Ea08ca3217527;
        allowedContracts.add(tokenAddr1);
        allowedContracts.add(tokenAddr2);
        if (block.chainid == BSC_TESTNET_CHAIN_ID)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0x66aB77d5B1930b86875256b22ebD931EF34F81D7;
            WETH_TOKEN_ADDRESS = 0xEE503374CBC152Aa339214FD41877622578bC6c2;
            
            isAllowedToBridgeToChainId[tokenAddr1][ETH_KOVAN_CHAIN_ID] = true; // allow to bridge to kovan
            isAllowedToBridgeToChainId[tokenAddr2][ETH_KOVAN_CHAIN_ID] = true; // allow to bridge to kovan
        } else if (block.chainid == ETH_KOVAN_CHAIN_ID)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            WETH_TOKEN_ADDRESS = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
            
            isAllowedToBridgeToChainId[tokenAddr1][BSC_TESTNET_CHAIN_ID] = true; // allow to bridge to bsc testnet
            isAllowedToBridgeToChainId[tokenAddr2][BSC_TESTNET_CHAIN_ID] = true; // allow to bridge to bsc testnet
        }*/
        
        /* MAINNET */
        address tokenAddr1 = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840; // DEFT
        address tokenAddr2 = 0x44EB8f6C496eAA8e0321006d3c61d851f87685BD; // LAMBO
        if (block.chainid == ETH_MAINNET_CHAIN_ID)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            WETH_TOKEN_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
            
            isAllowedToBridgeToChainId[tokenAddr1][BSC_MAINNET_CHAIN_ID] = true; // allow to bridge to bsc
            isAllowedToBridgeToChainId[tokenAddr2][BSC_MAINNET_CHAIN_ID] = true; // allow to bridge to bsc
        } else if (block.chainid == BSC_MAINNET_CHAIN_ID)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
            WETH_TOKEN_ADDRESS = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
            
            isAllowedToBridgeToChainId[tokenAddr1][ETH_MAINNET_CHAIN_ID] = true; // allow to bridge to eth
            isAllowedToBridgeToChainId[tokenAddr2][ETH_MAINNET_CHAIN_ID] = true; // allow to bridge to eth
        }
    }
    
    function allowContract(address addr, bool isAllow)
        external
        onlyRole(ROLE_ADMIN)
    {
        if (isAllow)
        {
            allowedContracts.add(addr);
        } else
        {
            allowedContracts.remove(addr);
        }
    }
    
    function isAllowedContract(address addr)
        external
        view
        returns (bool)
    {
        return allowedContracts.contains(addr);
    }
    
    function allowChain(address token, uint chainId, bool isAllowed)
        external
        onlyRole(ROLE_ADMIN)
    {
        isAllowedToBridgeToChainId[token][chainId] = isAllowed;
    }
    
    function updateBeneficiaryAddress(address newBeneficiaryAddr)
        external
        onlyRole(ROLE_ADMIN)
    {
        beneficiaryAddress = newBeneficiaryAddr;
    }
    
    function getCurrentMintFee()
        public
        view
        returns(uint)
    {
        return lastGasPrice * GAS_PER_APPROVE;
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
        
        lastGasPrice = tx.gasprice;
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
        
        lastGasPrice = tx.gasprice;
    }
    
    function mintWithBurnProof(SourceProofOfBurn memory sourceProofOfBurn) 
        external
        payable
    {
        require(
            transactionStorage[sourceProofOfBurn.transactionHash] == States.Approved,
            "CCB: Transaction is not approved or already executed"
        );
        
        bytes32 transactionHash = keccak256(abi.encodePacked(
                msg.sender, sourceProofOfBurn.sourceTokenAddr, sourceProofOfBurn.amount, sourceProofOfBurn.sourceChainId, block.chainid, sourceProofOfBurn.sourceNonce
            ));
        require(
            transactionHash == sourceProofOfBurn.transactionHash,
            "CCB: Provided hash is invalid"
        );
        
        uint amountAsFee = getCurrentMintFee();
        require(
            msg.value >= amountAsFee,
            "CCB: Provided fee is too low"
        );
        payable(beneficiaryAddress).transfer(msg.value);
        
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(sourceProofOfBurn.sourceTokenAddr);
        IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
            iDefiFactoryToken.getUtilsContractAtPos(DEFT_STORAGE_CONTRACT_ID)
        );
        require(
            !iDeftStorageContract.isBotAddress(msg.sender),
            "CCB: Minting is temporary disabled!"
        );
        
        transactionStorage[sourceProofOfBurn.transactionHash] = States.Executed;
        
        iDefiFactoryToken.mintByBridge(msg.sender, sourceProofOfBurn.amount);
        
        emit ProofOfMint(msg.sender, sourceProofOfBurn.sourceTokenAddr, amountAsFee, sourceProofOfBurn.amount, transactionHash);
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
            isAllowedToBridgeToChainId[token][destinationChainId],
            "CCB: Destination chain is not allowed"
        );
        
        require(
            allowedContracts.contains(token),
            "CCB: Token address is not allowed"
        );
        
        IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
            iDefiFactoryToken.getUtilsContractAtPos(DEFT_STORAGE_CONTRACT_ID)
        );
        require(
            !iDeftStorageContract.isBotAddress(msg.sender),
            "CCB: Burning is temporary disabled!"
        );
        
        bytes32 transactionHash = keccak256(abi.encodePacked(
                msg.sender, token, amount, block.chainid, destinationChainId, currentNonce[token]
            ));
            
        transactionStorage[transactionHash] = States.Burned;
        
        iDefiFactoryToken.burnByBridge(msg.sender, amount);
        
        emit ProofOfBurn(msg.sender, token, amount, currentNonce[token], block.chainid, destinationChainId, transactionHash);
        currentNonce[token]++;
    }
}
