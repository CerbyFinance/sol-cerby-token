// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.4;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/IDeftStorageContract.sol";

contract DeftStorageContract is AccessControlEnumerable {
    
    mapping(address => bool) private isBotStorage;
    mapping(address => bool) private isHumanStorage;
    mapping(address => bool) private isExcludedFromBalanceStorage;
    
    mapping(address => mapping(address => uint)) private buyTimestampStorage;
    mapping(address => uint) private cooldownPeriodBuyStorage;
    mapping(address => uint) private cooldownPeriodSellStorage;
    
    mapping(address => mapping(address => uint)) private sentAtTimestamp;
    mapping(address => mapping(address => uint)) private receivedAtTimestamp;
    
    mapping(address => bool) private isDeftEthPair;
    
    uint private howManyLeadingZerosToBlock;
    mapping(uint => address) private matchingAddressWithLeadingZeros;
    
    address constant BURN_ADDRESS = address(0x0);
    
    event BulkMarkedAsBot(address[] addrs);
    event MarkedAsBot(address addr);
    event MarkedAsNotBot(address addr);
    
    event MarkedAsExcludedFromBalance(address addr, bool value);
    event MarkedAsHuman(address addr, bool value);
    event MarkedAsDeftEthPair(address addr, bool value);
    
    
    constructor() {
        
        howManyLeadingZerosToBlock = 8;
        matchingAddressWithLeadingZeros[1] = address(0x0fffFFFFFfFfffFfFfFFffFffFffFFfffFfFFFFf);
        matchingAddressWithLeadingZeros[2] = address(0x00FfFFfFFFfFFFFFfFfFfffFFFfffFfFffFfFFFf);
        matchingAddressWithLeadingZeros[3] = address(0x000FfFfffFFFFfFFfFFFFFfFFFfFffffFFffFfFF);
        matchingAddressWithLeadingZeros[4] = address(0x0000FfffFfFffFFfFffFfffFFfFFFffFFFffFfFf);
        matchingAddressWithLeadingZeros[5] = address(0x00000ffffFFffFFffffFfFffFFFfFFfFFffFffff);
        matchingAddressWithLeadingZeros[6] = address(0x000000FFfffFFFFFFffFffffFffFfFfFFFFfFFfF);
        matchingAddressWithLeadingZeros[7] = address(0x0000000FFfFFfffFffFfFffFFFfffffFffFFffFf);
        matchingAddressWithLeadingZeros[8] = address(0x00000000fFFFffffffFfFfFFffFfFffFFFfFffff);
        matchingAddressWithLeadingZeros[9] = address(0x000000000FfFFfFfFFFFFFfffFfFfFFffffFfFfF);
        matchingAddressWithLeadingZeros[10] = address(0x000000000FfFFfFfFFFFFFfffFfFfFFffffFfFfF);
        matchingAddressWithLeadingZeros[11] = address(0x0000000000FFFFFffFfFffFfFFFfFFFfffffFffF);
        matchingAddressWithLeadingZeros[12] = address(0x00000000000FfFFFfffFFFfFffFFFFFFFfffFFFF);
        
        
        _setupRole(ROLE_ADMIN, _msgSender());
        
        markAddressAsExcludedFromBalance(0xDEF1fAE3A7713173C168945b8704D4600B6Fc7B9, true); // Team Vesting Tokens
        markAddressAsBot(0xC25e850F6cedE52809014d4eeCCA402eb47bDC28); // Top1 listing bot
        
        _setupRole(ROLE_ADMIN, 0x0C344a302fC79d687A3f09A0ca97c17F36dCC756); // NoBotsTechV2
        _setupRole(ROLE_ADMIN, 0x01e835C7A3f7B51243229DfB85A1EA08a5512499); // Cross Chain Bridge Contract
        _setupRole(ROLE_ADMIN, 0xdEF78a28c78A461598d948bc0c689ce88f812AD8); // Cross Chain Bridge Wallet for blacklisting bots
        
        markAddressAsHuman(0xdEF78a28c78A461598d948bc0c689ce88f812AD8, true); // Cross Chain Bridge Wallet
        markAddressAsHuman(0x0C344a302fC79d687A3f09A0ca97c17F36dCC756, true); // NoBotsTechV2
        markAddressAsHuman(0xDef1C0ded9bec7F1a1670819833240f027b25EfF, true); // 0x: Exchange Proxy
        markAddressAsHuman(0x11111112542D85B3EF69AE05771c2dCCff4fAa26, true); // 1inch Router
        markAddressAsHuman(0xdb38ae75c5F44276803345f7F02e95A0aeEF5944, true); // 1inch Router
        markAddressAsHuman(0xDEF1fAE3A7713173C168945b8704D4600B6Fc7B9, true); // TeamVestingContract
        markAddressAsHuman(0xdef1fac7Bf08f173D286BbBDcBeeADe695129840, true); // DefiFactoryContract
        
        
        cooldownPeriodBuyStorage[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840] = 1 minutes;
        cooldownPeriodSellStorage[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840] = 10 minutes;
        
        
        if (block.chainid == 1)
        {
            markAddressAsHuman(0x881D40237659C251811CEC9c364ef91dC08D300C, true); // Metamask Swap Router
            markAddressAsHuman(0x74de5d4FCbf63E00296fd95d33236B9794016631, true); // metamask router wallet
            markAddressAsHuman(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, true); // uniswap router v2
            markPairAsDeftEthPair(0xFa6687922BF40FF51Bcd45F9FD339215a4869D82, true); // [deft, weth] uniswap pair
        } else if (block.chainid == 56)
        {
            markAddressAsHuman(0x10ED43C718714eb63d5aA57B78B54704E256024E, true); // pancake router v2
            markPairAsDeftEthPair(0x077324B361272dde2D757f8Ec6Eb59daAe794519, true); // [deft, wbnb] pancake pair
            markPairAsDeftEthPair(0x493E990CcC67F59A3000EfFA9d5b1417D54B6f99, true); // [deft, busd] pancake pair
        } else if (block.chainid == 137)
        {
            
        }
    }
    
    function getCooldownPeriods(address tokenAddr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint, uint)
    {
        return (cooldownPeriodBuyStorage[tokenAddr], cooldownPeriodSellStorage[tokenAddr]);
    }
    
    function updateCooldownPeriod(address tokenAddr, uint newCooldownBuyPeriod, uint newCooldownSellPeriod)
        public
        onlyRole(ROLE_ADMIN)
    {
        cooldownPeriodBuyStorage[tokenAddr] = newCooldownBuyPeriod;
        cooldownPeriodSellStorage[tokenAddr] = newCooldownSellPeriod;
    }
    
    function getSentAtTimestamp(address tokenAddr, address addr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint)
    {
        return sentAtTimestamp[tokenAddr][addr];
    }
    
    function getReceivedAtTimestamp(address tokenAddr, address addr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint)
    {
        return receivedAtTimestamp[tokenAddr][addr];
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
        sentAtTimestamp[tokenAddr][sender] = block.timestamp;
        receivedAtTimestamp[tokenAddr][recipient] = block.timestamp;
    }
    
    function isBotAddress(address addr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (bool)
    {
        return 
            hasLeadingZerosInAddress(addr) ||
            isBotStorage[addr] ||
            isContract(addr) && !isDeftEthPair[addr] && !isHumanStorage[addr];
    }
    
    function isHumanTransaction(address tokenAddr, address sender, address recipient)
        external
        onlyRole(ROLE_ADMIN)
        returns (IsHumanInfo memory output)
    {
        output.isSell = isDeftEthPair[recipient];
        output.isBuy = isDeftEthPair[sender];
        
        bool isBot;
        bool isFrontrunBuyBot = 
            (
                sentAtTimestamp[tokenAddr][recipient] + cooldownPeriodBuyStorage[tokenAddr] >= block.timestamp ||
                hasLeadingZerosInAddress(recipient)
            ) && 
            !isHumanStorage[recipient] &&
            !isDeftEthPair[recipient];
        bool isFrontrunSellBot =
            (
                receivedAtTimestamp[tokenAddr][sender] + cooldownPeriodSellStorage[tokenAddr] >= block.timestamp ||
                hasLeadingZerosInAddress(sender)
            ) && 
            !isHumanStorage[sender] &&
            !isDeftEthPair[sender];
            
        if (isFrontrunSellBot)
        {
            isBot = true;
            _markAddressAsBot(sender);
        } else if (isFrontrunBuyBot)
        {
            isBot = true;
            _markAddressAsBot(recipient);
        } else if (
                !output.isBuy && // isSell or isTransfer
                (
                    isContract(sender) && !isDeftEthPair[sender] && !isHumanStorage[sender] || // isContractSender
                    isBotStorage[sender] // isBlacklistedSender
                )
            )
        {
            isBot = true;
            _markAddressAsBot(sender);
        }
        output.isHumanTransaction = !isBot;
        
        return output;
    }
    
    function getHowManyLeadingZerosToBlock()
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint)
    {
        return howManyLeadingZerosToBlock;
    }
    
    function updateHowManyLeadingZerosToBlock(uint newHowManyLeadingZerosToBlock)
        external
        onlyRole(ROLE_ADMIN)
    {
        howManyLeadingZerosToBlock = newHowManyLeadingZerosToBlock;
    }
    
    function hasLeadingZerosInAddress(address addr)
        private
        view
        returns (bool)
    {
        return addr < matchingAddressWithLeadingZeros[howManyLeadingZerosToBlock];
    }
    
    function isContract(address addr) 
        private
        view
        returns (bool)
    {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
    
    function isExcludedFromBalance(address addr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (bool)
    {
        return isExcludedFromBalanceStorage[addr];
    }
    
    function isMarkedAsDeftEthPair(address addr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (bool)
    {
        return isDeftEthPair[addr];
    }
    
    function isMarkedAsHumanStorage(address addr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (bool)
    {
        return isHumanStorage[addr];
    }
    
    function isMarkedAsHumanStorageBulk(address[] memory addrs)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (address[] memory)
    {
        for(uint i = 0; i < addrs.length; i++)
        {
            if (!isHumanStorage[addrs[i]])
            {
                addrs[i] = BURN_ADDRESS;
            }
        }
        return addrs;
    }
    
    function isMarkedAsBotStorage(address addr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (bool)
    {
        return isBotStorage[addr];
    }
    
    function isMarkedAsBotStorageBulk(address[] memory addrs)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (address[] memory)
    {
        for(uint i = 0; i < addrs.length; i++)
        {
            if (!isBotStorage[addrs[i]])
            {
                addrs[i] = BURN_ADDRESS;
            }
        }
        return addrs;
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
    
    function bulkMarkAddressAsBot(address[] memory addrs)
        external
        onlyRole(ROLE_ADMIN)
    {
        for(uint i = 0; i<addrs.length; i++)
        {
            if(isBotStorage[addrs[i]])
            {
                addrs[i] = address(0x0);
            } else
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
        
        _markAddressAsBot(addr);
    }
    
    function _markAddressAsBot(address addr)
        private
    {
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
    
}