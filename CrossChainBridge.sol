// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/IDefiFactoryToken.sol";

contract CrossChainBridge is AccessControlEnumerable {
    event ProofOfBurn(address addr, uint amount, uint currentNonce, uint sourceChain, uint destinationChain, bytes32 transactionHash);
    event ProofOfMint(address addr, uint amountAsFee, uint finalAmount, bytes32 transactionHash);
    event ApprovedTransaction(bytes32 transactionHash);
    event BulkApprovedTransactions(bytes32[] transactionHashes);
    
    enum States{ Created, Burned, Approved, Executed }
    mapping(bytes32 => States) public transactionStorage;
    
    
    bytes32 public constant ROLE_APPROVER = keccak256("ROLE_APPROVER");
    bytes32 public constant ROLE_BENEFICIARY = keccak256("ROLE_BENEFICIARY");
    uint constant feeDenorm = 1e6;
    
    mapping (uint => uint) public chainIdToFee;
    uint public minAmountToBurn = 1 * 1e18;
    uint public currentNonce;
    address defiFactoryContract;
    
    struct SourceProofOfBurn {
        uint amount;
        uint sourceChainId;
        uint sourceNonce;
        bytes32 transactionHash;
    }
    
    constructor() {
        _setupRole(ROLE_ADMIN, msg.sender);
        _setupRole(ROLE_APPROVER, msg.sender);
        _setupRole(ROLE_BENEFICIARY, msg.sender);
        
        chainIdToFee[3] = 5e4; // to ropsten
        chainIdToFee[42] = 1e4; // to kovan
        
        defiFactoryContract = 0x3A1f0F8aFF439a2f103d926FBf2c2663aEE44315; // kovan
        //defiFactoryContract = 0x3Dec41e3222a02918468Bba4A235E131d31D71b2; // ropsten
    }
    
    function updateSettings(uint newMinAmountToBurn, address newDefiFactoryContract) 
        external
        onlyRole(ROLE_ADMIN)
    {
        newMinAmountToBurn = minAmountToBurn;
        defiFactoryContract = newDefiFactoryContract;
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
        
        uint amountAsFee = (sourceProofOfBurn.amount*chainIdToFee[block.chainid]) / feeDenorm;
        uint finalAmount = sourceProofOfBurn.amount - amountAsFee; 
        
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryContract);
        iDefiFactoryToken.mintByBridge(msg.sender, finalAmount);
        iDefiFactoryToken.mintByBridge(getRoleMember(ROLE_BENEFICIARY, 0), amountAsFee);
        
        emit ProofOfMint(msg.sender, amountAsFee, finalAmount, transactionHash);
    }
    
    function burnAndCreateProof(uint amount, uint destinationChain) 
        external
    {
        
        require(
            amount > minAmountToBurn,
            "CCB: Amount is greater than minimum allowed"
        );
        
        bytes32 transactionHash = keccak256(abi.encodePacked(
                msg.sender, amount, block.chainid, destinationChain, currentNonce
            ));
            
        transactionStorage[transactionHash] = States.Burned;
        
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryContract);
        iDefiFactoryToken.burnByBridge(msg.sender, amount);
        
        emit ProofOfBurn(msg.sender, amount, currentNonce, block.chainid, destinationChain, transactionHash);
        currentNonce++;
    }
}
