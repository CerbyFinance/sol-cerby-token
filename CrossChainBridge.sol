// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/IDefiFactoryToken.sol";

contract CrossChainBridge is AccessControlEnumerable {
    event ProofOfBurn(address addr, uint amount, uint currentNonce, uint sourceChain, uint destinationChain, bytes32 transactionHash);
    event ProofOfMint(address addr, uint amountAsFee, uint finalAmount, bytes32 transactionHash);
    event ApprovedTransaction(bytes32 transactionHash);
    event BulkApprovedTransactions(bytes32[] transactionHashes);
    event FeeUpdated(uint feeAmount);
    event MinimumAmountToBurnUpdated(uint newMinAmountToBurn);
    
    enum States{ Created, Burned, Approved, Executed }
    mapping(bytes32 => States) public transactionStorage;
    
    
    bytes32 public constant ROLE_APPROVER = keccak256("ROLE_APPROVER");
    uint constant feeDenorm = 1e6;
    uint public feePercent = 1e4;
    
    uint public minAmountToBurn = 1 * 1e18;
    uint public currentNonce;
    address public mainTokenContract;
    address public beneficiaryAddress;
    
    mapping (uint => bool) public isAllowedToBridgeToChainId;
    
    struct SourceProofOfBurn {
        uint amount;
        uint sourceChainId;
        uint sourceNonce;
        bytes32 transactionHash;
    }
    
    constructor() {
        _setupRole(ROLE_ADMIN, msg.sender);
        _setupRole(ROLE_APPROVER, msg.sender);
        
        beneficiaryAddress = msg.sender;
        
        if (block.chainid == 3)
        {
            updateMinimumAmountToBurn(1000e18); // min 1000 tokens to burn on ropsten
            updateFee(1e4); // to ropsten 1% fee
            isAllowedToBridgeToChainId[42] = true; // allow to bridge to kovan
            mainTokenContract = 0x3Dec41e3222a02918468Bba4A235E131d31D71b2; // ropsten mintable token
        } else if (block.chainid == 42)
        {
            updateMinimumAmountToBurn(5000e18); // min 5000 tokens to burn on kovan
            updateFee(5e3); // to kovan 1% fee
            isAllowedToBridgeToChainId[3] = true; // allow to bridge to ropsten
            mainTokenContract = 0x3A1f0F8aFF439a2f103d926FBf2c2663aEE44315; // kovan mintable token
        }
    }
    
    function allowChain(uint chainId, bool isAllowed)
        external
        onlyRole(ROLE_ADMIN)
    {
        isAllowedToBridgeToChainId[chainId] = isAllowed;
    }
    
    function updateFee(uint newFeePercent)
        public
        onlyRole(ROLE_ADMIN)
    {
        feePercent = newFeePercent;
        emit FeeUpdated(newFeePercent);
    }
    
    function updateMinimumAmountToBurn(uint newMinAmountToBurn)
        public
        onlyRole(ROLE_ADMIN)
    {
        minAmountToBurn = newMinAmountToBurn;
        emit MinimumAmountToBurnUpdated(newMinAmountToBurn);
    }
    
    function updateMainTokenContract(address newMainTokenContract) 
        external
        onlyRole(ROLE_ADMIN)
    {
        mainTokenContract = newMainTokenContract;
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
                msg.sender, sourceProofOfBurn.amount, sourceProofOfBurn.sourceChainId, block.chainid, sourceProofOfBurn.sourceNonce
            ));
        require(
            transactionHash == sourceProofOfBurn.transactionHash,
            "CCB: Provided hash is invalid"
        );
        
        transactionStorage[sourceProofOfBurn.transactionHash] = States.Executed;
        
        uint amountAsFee = (sourceProofOfBurn.amount*feePercent) / feeDenorm;
        uint finalAmount = sourceProofOfBurn.amount - amountAsFee; 
        
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(mainTokenContract);
        iDefiFactoryToken.mintByBridge(msg.sender, finalAmount);
        iDefiFactoryToken.mintByBridge(beneficiaryAddress, amountAsFee);
        
        emit ProofOfMint(msg.sender, amountAsFee, finalAmount, transactionHash);
    }
    
    function burnAndCreateProof(uint amount, uint destinationChainId) 
        external
    {
        require(
            block.chainid != destinationChainId,
            "CCB: Destination chain must be different from current chain"
        );
        require(
            isAllowedToBridgeToChainId[destinationChainId],
            "CCB: Destination chain is not allowed"
        );
        require(
            amount > minAmountToBurn,
            "CCB: Amount is greater than minimum allowed"
        );
        
        bytes32 transactionHash = keccak256(abi.encodePacked(
                msg.sender, amount, block.chainid, destinationChainId, currentNonce
            ));
            
        transactionStorage[transactionHash] = States.Burned;
        
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(mainTokenContract);
        iDefiFactoryToken.burnByBridge(msg.sender, amount);
        
        emit ProofOfBurn(msg.sender, amount, currentNonce, block.chainid, destinationChainId, transactionHash);
        currentNonce++;
    }
}
