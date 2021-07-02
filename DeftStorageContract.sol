// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.4;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/IDeftStorageContract.sol";

contract DeftStorageContract is AccessControlEnumerable {
    
    mapping(address => bool) private isBotStorage;
    mapping(address => bool) private isHumanStorage;
    mapping(address => bool) private isExcludedFromBalanceStorage;
    
    mapping(address => uint) private cooldownPeriodBuyStorage;
    mapping(address => uint) private cooldownPeriodSellStorage;
    
    mapping(address => mapping(address => uint)) private buyTimestampStorage;
    
    mapping(address => bool) private isDeftEthPair;
    bool public isZeroGweiAllowed = false;
    
    uint private howManyLeadingZerosToBlock;
    mapping(uint => address) private matchingAddressWithLeadingZeros;
    
    address constant BURN_ADDRESS = address(0x0);
    uint constant DEFAULT_BUY_COOLDOWN = 0 seconds;
    uint constant DEFAULT_SELL_COOLDOWN = 5 minutes;
    uint constant BALANCE_DENORM = 1e18;
    
    uint constant ETH_MAINNET_CHAIN_ID = 1;
    uint constant ETH_ROPSTEN_CHAIN_ID = 3;
    uint constant ETH_KOVAN_CHAIN_ID = 42;
    uint constant BSC_MAINNET_CHAIN_ID = 56;
    uint constant BSC_TESTNET_CHAIN_ID = 97;
    
    constructor() {
        howManyLeadingZerosToBlock = 8;
        matchingAddressWithLeadingZeros[5] = address(0x00000ffffFFffFFffffFfFffFFFfFFfFFffFffff);
        matchingAddressWithLeadingZeros[6] = address(0x000000FFfffFFFFFFffFffffFffFfFfFFFFfFFfF);
        matchingAddressWithLeadingZeros[7] = address(0x0000000FFfFFfffFffFfFffFFFfffffFffFFffFf);
        matchingAddressWithLeadingZeros[8] = address(0x00000000fFFFffffffFfFfFFffFfFffFFFfFffff);
        
        _setupRole(ROLE_ADMIN, _msgSender());
        _setupRole(ROLE_ADMIN, 0x0C344a302fC79d687A3f09A0ca97c17F36dCC756); // NoBotsTechV2
        _setupRole(ROLE_ADMIN, 0x01e835C7A3f7B51243229DfB85A1EA08a5512499); // Cross Chain Bridge Contract
        _setupRole(ROLE_ADMIN, 0xdEF78a28c78A461598d948bc0c689ce88f812AD8); // Cross Chain Bridge Wallet for blacklisting bots
        
        markAddressAsExcludedFromBalance(0xDEF1fAE3A7713173C168945b8704D4600B6Fc7B9, true); // Team Vesting Tokens
        markAddressAsBot(0xC25e850F6cedE52809014d4eeCCA402eb47bDC28); // Top1 listing bot
        
        markAddressAsHuman(0xdEF78a28c78A461598d948bc0c689ce88f812AD8, true); // Cross Chain Bridge Wallet
        markAddressAsHuman(0x0C344a302fC79d687A3f09A0ca97c17F36dCC756, true); // NoBotsTechV2
        markAddressAsHuman(0xDef1C0ded9bec7F1a1670819833240f027b25EfF, true); // 0x: Exchange Proxy
        markAddressAsHuman(0x11111112542D85B3EF69AE05771c2dCCff4fAa26, true); // 1inch Router
        markAddressAsHuman(0xDEF1fAE3A7713173C168945b8704D4600B6Fc7B9, true); // TeamVestingContract
        markAddressAsHuman(0xdef1fac7Bf08f173D286BbBDcBeeADe695129840, true); // DefiFactoryContract
        
        
        cooldownPeriodBuyStorage[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840] = DEFAULT_BUY_COOLDOWN;
        cooldownPeriodSellStorage[0xdef1fac7Bf08f173D286BbBDcBeeADe695129840] = DEFAULT_SELL_COOLDOWN;
        
        if (block.chainid == ETH_MAINNET_CHAIN_ID)
        {
            markAddressAsHuman(0x881D40237659C251811CEC9c364ef91dC08D300C, true); // Metamask Swap Router
            markAddressAsHuman(0x74de5d4FCbf63E00296fd95d33236B9794016631, true); // metamask router wallet
            markAddressAsHuman(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, true); // uniswap router v2
            markPairAsDeftEthPair(0xFa6687922BF40FF51Bcd45F9FD339215a4869D82, true); // [deft, weth] uniswap pair
        } else if (block.chainid == BSC_MAINNET_CHAIN_ID)
        {
            markAddressAsHuman(0x10ED43C718714eb63d5aA57B78B54704E256024E, true); // pancake router v2
            markPairAsDeftEthPair(0x077324B361272dde2D757f8Ec6Eb59daAe794519, true); // [deft, wbnb] pancake pair
            markPairAsDeftEthPair(0x493E990CcC67F59A3000EfFA9d5b1417D54B6f99, true); // [deft, busd] pancake pair
            isZeroGweiAllowed = true;
        }
    }
    
    function updateIsZeroGweiAllowed(bool _isZeroGweiAllowed)
        public
        onlyRole(ROLE_ADMIN)
    {
        isZeroGweiAllowed = _isZeroGweiAllowed;
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
        
        uint defaultSellCooldown = cooldownPeriodSellStorage[tokenAddr] > 0? cooldownPeriodSellStorage[tokenAddr]: DEFAULT_SELL_COOLDOWN;
        bool isBot;
        bool isZeroGweiAllowedForBots = !(isZeroGweiAllowed && tx.gasprice == 0);
            
        if (
                output.isBuy && 
                tx.origin != recipient && // isOriginBot
                !isContract(recipient) && 
                !isHumanStorage[recipient] &&
                isZeroGweiAllowedForBots 
            )
        {
            _markAddressAsBot(recipient);
        } else if(
                !output.isBuy && // isSell or isTransfer
                (
                    isContract(sender) && !isDeftEthPair[sender] && !isHumanStorage[sender] || // isContractSender
                    isBotStorage[sender] || // isBlacklistedSender
                    buyTimestampStorage[tokenAddr][sender] + defaultSellCooldown >= block.timestamp ||
                    hasLeadingZerosInAddress(sender)
                ) &&
                isZeroGweiAllowedForBots
            )
        {
            if (output.isSell) // 99.9% tax only on sells
            {
                isBot = true;
            } else // isTransfer
            {
                _markAddressAsBot(recipient); // passing bot decease
            }
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
    }
    
    function markAddressAsHuman(address addr, bool value)
        public
        onlyRole(ROLE_ADMIN)
    {
        isHumanStorage[addr] = value;
    }
    
    function markPairAsDeftEthPair(address addr, bool value)
        public
        onlyRole(ROLE_ADMIN)
    {
        isDeftEthPair[addr] = value;
    }
    
    function bulkMarkAddressAsBot(address[] memory addrs)
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
    }
}