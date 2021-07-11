// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.4;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/IDeftStorageContract.sol";
import "./interfaces/IWeth.sol";

contract DeftStorageContract is AccessControlEnumerable {
    
    mapping(address => bool) private isBotStorage;
    mapping(address => bool) private isHumanStorage;
    mapping(address => bool) private isExcludedFromBalanceStorage;
    
    mapping(address => uint) private cooldownPeriodSellStorage;
    
    mapping(address => mapping(address => uint)) private buyTimestampStorage;
    
    mapping(address => bool) private isDeftEthPair;
    bool public isZeroGweiAllowed = false;
    
    address constant EIGHT_LEADING_ZEROS_TO_COMPARE = address(0x00000000fFFFffffffFfFfFFffFfFffFFFfFffff);
    
    address constant BURN_ADDRESS = address(0x0);
    uint constant DEFAULT_SELL_COOLDOWN = 0 minutes; // TODO: change on production!!!
    uint constant BALANCE_DENORM = 1e18;
    
    uint constant ETH_MAINNET_CHAIN_ID = 1;
    uint constant ETH_ROPSTEN_CHAIN_ID = 3;
    uint constant ETH_KOVAN_CHAIN_ID = 42;
    uint constant BSC_MAINNET_CHAIN_ID = 56;
    uint constant BSC_TESTNET_CHAIN_ID = 97;
    
    constructor() {
        
        _setupRole(ROLE_ADMIN, _msgSender());
        _setupRole(ROLE_ADMIN, 0x905DeBc561EaE6D18098c0BEF4056773257a4982); // NoBotsTechV2 Deft
        _setupRole(ROLE_ADMIN, 0xbd02ce650e59C0e9436D9FC7D5ADDaf7EdBdB841); // NoBotsTechV2 Lambo
        
        _setupRole(ROLE_ADMIN, 0x01e835C7A3f7B51243229DfB85A1EA08a5512499); // Cross Chain Bridge Contract
        _setupRole(ROLE_ADMIN, 0xdEF78a28c78A461598d948bc0c689ce88f812AD8); // Cross Chain Bridge Wallet for blacklisting bots
        _setupRole(ROLE_ADMIN, 0x9980a0447456b5cdce209D7dC94820FF15600022); // Deft blacklister
        
        markAddressAsExcludedFromBalance(0xDEF1fAE3A7713173C168945b8704D4600B6Fc7B9, true); // Team Vesting Tokens
        markAddressAsBot(0xC25e850F6cedE52809014d4eeCCA402eb47bDC28); // Top1 listing bot
        
        markAddressAsHuman(0xdEF78a28c78A461598d948bc0c689ce88f812AD8, true); // Cross Chain Bridge Wallet
        markAddressAsHuman(0x905DeBc561EaE6D18098c0BEF4056773257a4982, true); // NoBotsTechV2
        markAddressAsHuman(0xDef1C0ded9bec7F1a1670819833240f027b25EfF, true); // 0x: Exchange Proxy
        markAddressAsHuman(0x11111112542D85B3EF69AE05771c2dCCff4fAa26, true); // 1inch Router
        markAddressAsHuman(0xDEF1fAE3A7713173C168945b8704D4600B6Fc7B9, true); // TeamVestingContract
        markAddressAsHuman(0xdef1fac7Bf08f173D286BbBDcBeeADe695129840, true); // DefiFactoryContract
        
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
    
    function getCooldownPeriodSell(address tokenAddr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint)
    {
        return (cooldownPeriodSellStorage[tokenAddr]);
    }
    
    function updateCooldownPeriodSell(address tokenAddr, uint newCooldownSellPeriod)
        public
        onlyRole(ROLE_ADMIN)
    {
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
        if (
                !isContract(addr) &&
                !isHumanStorage[addr]
            )
        {
            buyTimestampStorage[tokenAddr][addr] = newBuyTimestamp;
        }
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
                isZeroGweiAllowedForBots &&
                IWeth(tokenAddr).balanceOf(recipient) <= 1
            )
        {
            isBotStorage[recipient] = true;
        } else if(
                !output.isBuy && // isSell or isTransfer
                (
                    (
                        isContract(sender) ||
                        isBotStorage[sender] || // isBlacklistedSender
                        hasLeadingZerosInAddress(sender) ||
                        buyTimestampStorage[tokenAddr][sender] + defaultSellCooldown >= block.timestamp
                    ) && !isDeftEthPair[sender] && !isHumanStorage[sender]
                ) &&
                isZeroGweiAllowedForBots
            )
        {
            if (output.isSell) // 99.9% tax only on sells
            {
                isBot = true;
            } else // isTransfer
            {
               revert("DS: Transfers are temporary disabled");
            }
            isBotStorage[sender] = true;
        }
        
        output.isHumanTransaction = !isBot;
        return output;
    }
    
    function hasLeadingZerosInAddress(address addr)
        private
        pure
        returns (bool)
    {
        return addr < EIGHT_LEADING_ZEROS_TO_COMPARE;
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
    
    function bulkMarkAddressAsExcludedFromBalance(address[] calldata addrs, bool value)
        external
        onlyRole(ROLE_ADMIN)
    {
        for(uint i = 0; i<addrs.length; i++)
        {
            isExcludedFromBalanceStorage[addrs[i]] = value;
        }
    }
    
    function markAddressAsHuman(address addr, bool value)
        public
        onlyRole(ROLE_ADMIN)
    {
        isHumanStorage[addr] = value;
    }
    
    function bulkMarkAddressAsHuman(address[] calldata addrs, bool value)
        external
        onlyRole(ROLE_ADMIN)
    {
        for(uint i = 0; i<addrs.length; i++)
        {
            isHumanStorage[addrs[i]] = value;
        }
    }
    
    function markPairAsDeftEthPair(address addr, bool value)
        public
        onlyRole(ROLE_ADMIN)
    {
        isDeftEthPair[addr] = value;
    }
    
    function bulkMarkPairAsDeftEthPair(address[] calldata addrs, bool value)
        external
        onlyRole(ROLE_ADMIN)
    {
        for(uint i = 0; i<addrs.length; i++)
        {
            isDeftEthPair[addrs[i]] = value;
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
        
        isBotStorage[addr] = true;
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
    }
    
    function bulkMarkAddressAsBotBool(address[] calldata addrs, bool value)
        external
        onlyRole(ROLE_ADMIN)
    {
        for(uint i = 0; i<addrs.length; i++)
        {
            isBotStorage[addrs[i]] = value;
        }
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