// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./openzeppelin/utils/structs/EnumerableSet.sol";
import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/IDeftStorageContract.sol";

contract CrossChainBridge is AccessControlEnumerable {
    event ProofOfBurn(address addr, address token, uint amount, uint currentNonce, uint sourceChain, uint destinationChain, bytes32 transactionHash);
    event ProofOfMint(address addr, address token, uint amountAsFee, uint finalAmount, bytes32 transactionHash);
    event ApprovedTransaction(bytes32 transactionHash);
    event BulkApprovedTransactions(bytes32[] transactionHashes);
    event FeeUpdated(uint newFeePercent);
    
    enum States{ Created, Burned, Approved, Executed }
    mapping(bytes32 => States) public transactionStorage;
    
    
    uint constant NO_BOTS_TECH_CONTRACT_ID = 0;
    uint constant DEFT_STORAGE_CONTRACT_ID = 3;
    bytes32 public constant ROLE_APPROVER = keccak256("ROLE_APPROVER");
    
    uint constant feeDenorm = 1e6;
    uint public feePercent;
    
    uint constant BOT_TAX_PERCENT = 999e3;
    uint constant TAX_PERCENT_DENORM = 1e6;
    
    mapping(address => uint) public currentNonce;
    address public beneficiaryAddress;
    
    mapping(address => mapping (uint => bool)) public isAllowedToBridgeToChainId;
    
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private allowedContracts;
    
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
        _setupRole(ROLE_APPROVER, 0xdEF78a28c78A461598d948bc0c689ce88f812AD8);
        
        beneficiaryAddress = 0xdEF78a28c78A461598d948bc0c689ce88f812AD8;
        
        updateFee(5e5); // 0.5% fee to any directions
        
        address tokenAddr1 = 0xdEF78a28c78A461598d948bc0c689ce88f812AD8;
        address tokenAddr2 = 0xdEF78a28c78A461598d948bc0c689ce88f812AD8;
        if (block.chainid == 97)
        {
            isAllowedToBridgeToChainId[tokenAddr1][42] = true; // allow to bridge to kovan
            isAllowedToBridgeToChainId[tokenAddr2][42] = true; // allow to bridge to kovan
        } else if (block.chainid == 42)
        {
            isAllowedToBridgeToChainId[tokenAddr1][97] = true; // allow to bridge to bsc testnet
            isAllowedToBridgeToChainId[tokenAddr2][97] = true; // allow to bridge to bsc testnet
        }
        
        /* MAINNET
        address tokenAddr1 = 0xdEF78a28c78A461598d948bc0c689ce88f812AD8;
        address tokenAddr2 = 0xdEF78a28c78A461598d948bc0c689ce88f812AD8;
        if (block.chainid == 1)
        {
            isAllowedToBridgeToChainId[tokenAddr1][56] = true; // allow to bridge to bsc
            isAllowedToBridgeToChainId[tokenAddr2][137] = true; // allow to bridge to matic
        } else if (block.chainid == 56)
        {
            isAllowedToBridgeToChainId[tokenAddr1][1] = true; // allow to bridge to eth
            isAllowedToBridgeToChainId[tokenAddr2][137] = true; // allow to bridge to matic
        } else if (block.chainid == 137)
        {
            isAllowedToBridgeToChainId[tokenAddr1][1] = true; // allow to bridge to eth
            isAllowedToBridgeToChainId[tokenAddr2][56] = true; // allow to bridge to bsc
        }*/
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
    
    function updateFee(uint newFeePercent)
        public
        onlyRole(ROLE_ADMIN)
    {
        feePercent = newFeePercent;
        emit FeeUpdated(newFeePercent);
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
                msg.sender, sourceProofOfBurn.sourceTokenAddr, sourceProofOfBurn.amount, sourceProofOfBurn.sourceChainId, block.chainid, sourceProofOfBurn.sourceNonce
            ));
        require(
            transactionHash == sourceProofOfBurn.transactionHash,
            "CCB: Provided hash is invalid"
        );
        
        transactionStorage[sourceProofOfBurn.transactionHash] = States.Executed;
        
        uint amountAsFee = (sourceProofOfBurn.amount*feePercent) / feeDenorm;
        uint finalAmount = sourceProofOfBurn.amount - amountAsFee; 
        
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(sourceProofOfBurn.sourceTokenAddr);
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
            isAllowedToBridgeToChainId[token][destinationChainId],
            "CCB: Destination chain is not allowed"
        );
        
        require(
            amount > getMinAmountToBurn(),
            "CCB: Amount is lower than the minimum permitted amount"
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
            "CCB: Bots aren't allowed to bridge!"
        );
        
        bytes32 transactionHash = keccak256(abi.encodePacked(
                msg.sender, token, amount, block.chainid, destinationChainId, currentNonce[token]
            ));
            
        transactionStorage[transactionHash] = States.Burned;
        
        iDefiFactoryToken.burnByBridge(msg.sender, amount);
        
        emit ProofOfBurn(msg.sender, token, amount, currentNonce[token], block.chainid, destinationChainId, transactionHash);
        currentNonce[token]++;
    }
    
    //  TODO: add code
    function getMinAmountToBurn()
        public
        view
        returns (uint)
    {
        return 123;
    }
    
    function getSettings(address token)
        public
        view
        returns (bool, uint, uint)
    {
        return (allowedContracts.contains(token), getMinAmountToBurn(), feePercent);
    }
}
