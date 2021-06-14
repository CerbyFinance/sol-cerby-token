// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.4;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/IDeftStorageContract.sol";

contract DeftStorageContract is AccessControlEnumerable {
    
    mapping(address => bool) private isBotStorage;
    mapping(address => bool) private isHumanStorage;
    mapping(address => bool) private isExcludedFromBalanceStorage;
    
    mapping(address => mapping(address => uint)) private buyTimestampStorage;
    
    mapping(address => mapping(address => uint)) private sentAtBlock;
    mapping(address => mapping(address => uint)) private receivedAtBlock;
    
    mapping(address => bool) private isDeftEthPair;
    
    
    
    mapping(bytes32 => uint256)    private uIntStorage;
    mapping(bytes32 => string)     private stringStorage;
    mapping(bytes32 => address)    private addressStorage;
    mapping(bytes32 => bytes)      private bytesStorage;
    mapping(bytes32 => bool)       private boolStorage;
    mapping(bytes32 => int256)     private intStorage;
    mapping(bytes32 => bytes32)    private bytes32Storage;



    
    event BulkMarkedAsBot(address[] addrs);
    event MarkedAsBot(address addr);
    event MarkedAsNotBot(address addr);
    
    event MarkedAsExcludedFromBalance(address addr, bool value);
    event MarkedAsHuman(address addr, bool value);
    event MarkedAsDeftEthPair(address addr, bool value);
    
    
    constructor() {
        _setupRole(ROLE_ADMIN, _msgSender());
        
        markAddressAsExcludedFromBalance(0xDEF1fAE3A7713173C168945b8704D4600B6Fc7B9, true); // Team Vesting Tokens
        markAddressAsBot(0xC25e850F6cedE52809014d4eeCCA402eb47bDC28); // Top1 listing bot
        
        _setupRole(ROLE_ADMIN, 0xc89302c356A100A01bd235295b62eeA4D19CB6A5); // cross chain contract
        _setupRole(ROLE_ADMIN, 0xdEF78a28c78A461598d948bc0c689ce88f812AD8); // cross chain wallet
        markAddressAsHuman(0xdEF78a28c78A461598d948bc0c689ce88f812AD8, true); // cross chain wallet
        
        if (block.chainid == 1)
        {
            markAddressAsHuman(0x74de5d4FCbf63E00296fd95d33236B9794016631, true); // metamask router contract
            markAddressAsHuman(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, true); // uniswap router v2
            markPairAsDeftEthPair(0xFa6687922BF40FF51Bcd45F9FD339215a4869D82, true); // [deft, weth] uniswap pair
        } else if (block.chainid == 56)
        {
            
        } else if (block.chainid == 137)
        {
            
        }
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
                ) ||
            hasLeadingZerosInAddress(recipient);
        bool isFrontrunBuyBot =
            receivedAtBlock[tokenAddr][sender] == block.number && 
                !(
                    isHumanStorage[sender] ||
                    isDeftEthPair[sender]
                ) ||
            hasLeadingZerosInAddress(sender);
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
    
    function hasLeadingZerosInAddress(address addr)
        private
        pure
        returns (bool)
    {
        return address(addr) < address(0x00000000fFFFffffffFfFfFFffFfFffFFFfFffff);
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
    
    function isExcludedFromBalance(address addr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (bool)
    {
        return isExcludedFromBalanceStorage[addr];
    }
    
    function markAddressAsExcludedFromBalance(address addr, bool value)
        public
        onlyRole(ROLE_ADMIN)
    {
        isExcludedFromBalanceStorage[addr] = value;
        emit MarkedAsExcludedFromBalance(addr, value);
    }
    
    function markAddressAsHuman(address addr, bool value)
        public
        onlyRole(ROLE_ADMIN)
    {
        isHumanStorage[addr] = value;
        emit MarkedAsHuman(addr, value);
    }
    
    function markPairAsDeftEthPair(address addr, bool value)
        public
        onlyRole(ROLE_ADMIN)
    {
        isDeftEthPair[addr] = value;
        emit MarkedAsDeftEthPair(addr, value);
    }
    
    function bulkMarkAddressAsBot(address[] calldata addrs)
        external
        onlyRole(ROLE_ADMIN)
    {
        for(uint i = 0; i<addrs.length; i++)
        {
            if(!isBotStorage[addrs[i]])
            {
                isBotStorage[addrs[i]] = true;
            }
        }
        emit BulkMarkedAsBot(addrs);
    }
    
    function markAddressAsBot(address addr)
        public
        onlyRole(ROLE_ADMIN)
    {
        require(
            !isBotStorage[addr],
            "DS: bot"
        );
        
        isBotStorage[addr] = true;
        emit MarkedAsBot(addr);
    }
    
    function markAddressAsNotBot(address addr)
        external
        onlyRole(ROLE_ADMIN)
    {
        require(
            isBotStorage[addr],
            "DS: !bot"
        );
        
        isBotStorage[addr] = false;
        emit MarkedAsNotBot(addr);
    }
    
    
    /* ------------------------------- */
    
    
    
    /// @param _key The key for the record
    function getAddress(bytes32 _key)
        external 
        view 
        onlyRole(ROLE_ADMIN)
        returns (address) 
    {
        return addressStorage[_key];
    }

    /// @param _key The key for the record
    function getUint(bytes32 _key)
        external 
        view 
        onlyRole(ROLE_ADMIN)
        returns (uint) 
    {
        return uIntStorage[_key];
    }

    /// @param _key The key for the record
    function getString(bytes32 _key)
        external 
        view 
        onlyRole(ROLE_ADMIN)
        returns (string memory) 
    {
        return stringStorage[_key];
    }

    /// @param _key The key for the record
    function getBytes(bytes32 _key)
        external 
        view 
        onlyRole(ROLE_ADMIN)
        returns (bytes memory) 
    {
        return bytesStorage[_key];
    }

    /// @param _key The key for the record
    function getBool(bytes32 _key)
        external 
        view 
        onlyRole(ROLE_ADMIN)
        returns (bool) 
    {
        return boolStorage[_key];
    }

    /// @param _key The key for the record
    function getInt(bytes32 _key)
        external 
        view 
        onlyRole(ROLE_ADMIN)
        returns (int) 
    {
        return intStorage[_key];
    }

    /// @param _key The key for the record
    function getBytes32(bytes32 _key)
        external 
        view 
        onlyRole(ROLE_ADMIN)
        returns (bytes32) 
    {
        return bytes32Storage[_key];
    }


    /// @param _key The key for the record
    function setAddress(bytes32 _key, address _value)
        external
        onlyRole(ROLE_ADMIN)
    {
        addressStorage[_key] = _value;
    }

    /// @param _key The key for the record
    function setUint(bytes32 _key, uint _value)
        external
        onlyRole(ROLE_ADMIN)
    {
        uIntStorage[_key] = _value;
    }

    /// @param _key The key for the record
    function setString(bytes32 _key, string calldata _value)
        external
        onlyRole(ROLE_ADMIN)
    {
        stringStorage[_key] = _value;
    }

    /// @param _key The key for the record
    function setBytes(bytes32 _key, bytes calldata _value)
        external
        onlyRole(ROLE_ADMIN)
    {
        bytesStorage[_key] = _value;
    }
    
    /// @param _key The key for the record
    function setBool(bytes32 _key, bool _value)
        external
        onlyRole(ROLE_ADMIN)
    {
        boolStorage[_key] = _value;
    }
    
    /// @param _key The key for the record
    function setInt(bytes32 _key, int _value)
        external
        onlyRole(ROLE_ADMIN)
    {
        intStorage[_key] = _value;
    }

    /// @param _key The key for the record
    function setBytes32(bytes32 _key, bytes32 _value)
        external
        onlyRole(ROLE_ADMIN)
    {
        bytes32Storage[_key] = _value;
    }


    /// @param _key The key for the record
    function deleteAddress(bytes32 _key)
        external
        onlyRole(ROLE_ADMIN)
    {
        delete addressStorage[_key];
    }

    /// @param _key The key for the record
    function deleteUint(bytes32 _key)
        external
        onlyRole(ROLE_ADMIN)
    {
        delete uIntStorage[_key];
    }

    /// @param _key The key for the record
    function deleteString(bytes32 _key)
        external
        onlyRole(ROLE_ADMIN)
    {
        delete stringStorage[_key];
    }

    /// @param _key The key for the record
    function deleteBytes(bytes32 _key)
        external
        onlyRole(ROLE_ADMIN)
    {
        delete bytesStorage[_key];
    }
    
    /// @param _key The key for the record
    function deleteBool(bytes32 _key)
        external
        onlyRole(ROLE_ADMIN)
    {
        delete boolStorage[_key];
    }
    
    /// @param _key The key for the record
    function deleteInt(bytes32 _key)
        external
        onlyRole(ROLE_ADMIN)
    {
        delete intStorage[_key];
    }

    /// @param _key The key for the record
    function deleteBytes32(bytes32 _key)
        external
        onlyRole(ROLE_ADMIN)
    {
        delete bytes32Storage[_key];
    }
}