// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/IDeftStorageContract.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";


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
    
    mapping(address => mapping (uint => uint)) feeDependingOnDestinationChainId;
    
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
        
        
        beneficiaryAddress = APPROVER_WALLET;
        
        
        /* Testnet */
        if (block.chainid == ETH_KOVAN_CHAIN_ID)
        {
            _setupRole(ROLE_ADMIN, 0x539FaA851D86781009EC30dF437D794bCd090c8F);
            _setupRole(ROLE_APPROVER, 0x539FaA851D86781009EC30dF437D794bCd090c8F);
            
            feeDependingOnDestinationChainId[0x40A24Fe8E4F7dDd2F614C0BC7e3d405b60f6a248][BSC_TESTNET_CHAIN_ID] = 1e5 * 1e18; // allow to bridge to bsc
        } else if (block.chainid == BSC_TESTNET_CHAIN_ID)
        {
            _setupRole(ROLE_ADMIN, 0x539FaA851D86781009EC30dF437D794bCd090c8F);
            _setupRole(ROLE_APPROVER, 0x539FaA851D86781009EC30dF437D794bCd090c8F);
            
            feeDependingOnDestinationChainId[0x40A24Fe8E4F7dDd2F614C0BC7e3d405b60f6a248][ETH_KOVAN_CHAIN_ID] = 2e6 * 1e18; // allow to bridge to eth
        }
        
        /* MAINNET */
        if (block.chainid == ETH_MAINNET_CHAIN_ID)
        {
            feeDependingOnDestinationChainId[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840][BSC_MAINNET_CHAIN_ID] = 1e5 * 1e18; // allow to bridge to bsc
            feeDependingOnDestinationChainId[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840][MATIC_MAINNET_CHAIN_ID] = 1e5 * 1e18; // allow to bridge to polygon
        } else if (block.chainid == BSC_MAINNET_CHAIN_ID)
        {
            feeDependingOnDestinationChainId[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840][ETH_MAINNET_CHAIN_ID] = 2e6 * 1e18; // allow to bridge to eth
            feeDependingOnDestinationChainId[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840][MATIC_MAINNET_CHAIN_ID] = 1e5 * 1e18; // allow to bridge to polygon
        } else if (block.chainid == MATIC_MAINNET_CHAIN_ID)
        {
            feeDependingOnDestinationChainId[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840][ETH_MAINNET_CHAIN_ID] = 2e6 * 1e18; // allow to bridge to eth
            feeDependingOnDestinationChainId[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840][BSC_MAINNET_CHAIN_ID] = 1e5 * 1e18; // allow to bridge to bsc
        }
    }
    
    function getFeeDependingOnDestinationChainId(address tokenAddr, uint destinationChainId)
        public
        view
        returns(uint)
    {
        return feeDependingOnDestinationChainId[tokenAddr][destinationChainId];
    }
    
    function updateFeeDependingOnDestinationChainId(address token, uint chainId, uint amountAsFee)
        external
        onlyRole(ROLE_ADMIN)
    {
        feeDependingOnDestinationChainId[token][chainId] = amountAsFee;
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
        
        uint amountAsFeeHasToBeLargerThanZero = feeDependingOnDestinationChainId[sourceProofOfBurn.sourceTokenAddr][sourceProofOfBurn.sourceChainId];
        require(
            amountAsFeeHasToBeLargerThanZero > 0,
            "CCB: Destination is forbidden (mint)"
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
        
        uint amountAsFee = feeDependingOnDestinationChainId[token][destinationChainId];
        require(
            amountAsFee > 0,
            "CCB: Destination is forbidden (burn)"
        );
        require(
            amount > amountAsFee,
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
                msg.sender, token, amount, amountAsFee, block.chainid, destinationChainId, currentNonce[token]
            ));
            
        transactionStorage[transactionHash] = States.Burned;
        
        iDefiFactoryToken.burnByBridge(msg.sender, amount);
        iDefiFactoryToken.mintHumanAddress(beneficiaryAddress, amountAsFee);
        
        emit ProofOfBurn(msg.sender, token, amount, amountAsFee, currentNonce[token], block.chainid, destinationChainId, transactionHash);
        currentNonce[token]++;
    }
}