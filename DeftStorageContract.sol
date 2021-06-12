// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.4;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/IDeftStorageContract.sol";

contract DeftStorageContract is AccessControlEnumerable {
    
    mapping(address => bool) private isBotStorage;
    mapping(address => bool) private isHumanStorage;
    
    mapping(address => mapping(address => uint)) private buyTimestampStorage;
    
    mapping(address => mapping(address => uint)) private sentAtBlock;
    mapping(address => mapping(address => uint)) private receivedAtBlock;
    
    mapping(address => bool) private isDeftEthPair;
    
    event BulkMarkedAsBot(address[] addrs);
    event MarkedAsBot(address addr);
    event MarkedAsNotBot(address addr);
    
    constructor() {
        _setupRole(ROLE_ADMIN, _msgSender());
    }
    
    function getBuyTimestamp(address tokenAddr, address addr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint)
    {
        return buyTimestampStorage[tokenAddr][addr];
    }
    
    function updateBuyTimestamp(address tokenAddr, address addr, uint newBuyTimestamp)
        public
        onlyRole(ROLE_ADMIN)
    {
        buyTimestampStorage[tokenAddr][addr] = newBuyTimestamp;
    }
    
    function updateTransaction(address tokenAddr, address sender, address recipient)
        external
        onlyRole(ROLE_ADMIN)
    {
        sentAtBlock[tokenAddr][sender] = block.number;
        receivedAtBlock[tokenAddr][recipient] = block.number;
    }
    
    function isBotAddress(address addr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (bool)
    {
        return isBotStorage[addr] ||
            !isNotContract(addr) && !isDeftEthPair[addr];
    }
    
    function isHumanTransaction(address tokenAddr, address sender, address recipient)
        external
        onlyRole(ROLE_ADMIN)
        returns (IsHumanInfo memory output)
    {
        /*bool isSell = isDeftEthPair[recipient];
        bool isBuy = isDeftEthPair[sender];
        bool isBuyOtherTokenThroughDeft = isDeftEthPair[sender] && isDeftOtherPair[recipient];
        bool isSellOtherTokenThroughDeft = isDeftOtherPair[sender] && isDeftEthPair[recipient];
        bool isBlacklisted = isBotStorage[recipient] || isBotStorage[sender];
        bool isFrontrunBot = 
            sentAtBlock[tokenAddr][recipient] == block.number && !isHumanStorage[recipient] ||
            receivedAtBlock[tokenAddr][sender] == block.number && !isHumanStorage[sender];
        bool isContractSender = !(isNotContract(sender) || isDeftOtherPair[sender] || isDeftEthPair[sender]);
        bool isContractRecipient = !(isNotContract(recipient) || isDeftOtherPair[recipient] || isDeftEthPair[recipient]);*/
        
        output.isSell = isDeftEthPair[recipient];
        output.isBuy = isDeftEthPair[sender];
        
        bool isBot;
        bool isFrontrunSellBot = 
            sentAtBlock[tokenAddr][recipient] == block.number && 
                !(
                    isHumanStorage[recipient] ||
                    isDeftEthPair[recipient]
                );
        bool isFrontrunBuyBot =
            receivedAtBlock[tokenAddr][sender] == block.number && 
                !(
                    isHumanStorage[sender] ||
                    isDeftEthPair[sender]
                );
        if (isFrontrunSellBot)
        {
            isBot = true;
            markAddressAsBot(recipient);
        } else if (isFrontrunBuyBot)
        {
            isBot = true;
            markAddressAsBot(sender);
        } else if (
                !output.isBuy && // isSell or isTransfer
                (
                    !(
                        isNotContract(sender) || 
                        isDeftEthPair[sender] || 
                        isHumanStorage[sender]
                    ) || // isContractSender
                    isBotStorage[sender] // isBlacklistedSender
                )
            )
        {
            isBot = true;
        }
        output.isHumanTransaction = !isBot;
        
        return output;
    }
    
    function isNotContract(address addr) 
        private
        view
        returns (bool)
    {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size == 0;
    }
    
    function markAddressAsHuman(address addr, bool value)
        external
        onlyRole(ROLE_ADMIN)
    {
        isHumanStorage[addr] = value;
    }
    
    function markPairAsDeftEthPair(address addr, bool value)
        external
        onlyRole(ROLE_ADMIN)
    {
        isDeftEthPair[addr] = value;
    }
    
    function bulkMarkAddressAsBot(address[] calldata addrs)
        external
        onlyRole(ROLE_ADMIN)
    {
        for(uint i = 0; i<addrs.length; i++)
        {
            isBotStorage[addrs[i]] = true;
        }
        emit BulkMarkedAsBot(addrs);
    }
    
    function markAddressAsBot(address addr)
        public
        onlyRole(ROLE_ADMIN)
    {
        isBotStorage[addr] = true;
        emit MarkedAsBot(addr);
    }
    
    function markAddressAsNotBot(address addr)
        external
        onlyRole(ROLE_ADMIN)
    {
        isBotStorage[addr] = false;
        emit MarkedAsNotBot(addr);
    }
}