// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.4;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/IDeftStorageContract.sol";
import "./interfaces/IWeth.sol";

contract DeftStorageContract is AccessControlEnumerable {
    
    mapping(address => bool) private isBotStorage;
    mapping(address => bool) private isHumanStorage;
    
    mapping(address => uint) private cooldownPeriodSellStorage;
    
    mapping(address => mapping(address => uint)) private buyTimestampStorage;
    
    mapping(address => bool) private isUniswapPair;
    
    address constant BURN_ADDRESS = address(0x0);
    uint constant DEFAULT_SELL_COOLDOWN = 5 minutes; // TODO: change on production!!!
    uint constant BALANCE_DENORM = 1e18;
    
    uint constant ETH_MAINNET_CHAIN_ID = 1;
    uint constant BSC_MAINNET_CHAIN_ID = 56;
    uint constant POLYGON_MAINNET_CHAIN_ID = 137;
    
    uint constant BSC_TESTNET_CHAIN_ID = 97;
    uint constant ETH_ROPSTEN_CHAIN_ID = 3;
    uint constant ETH_KOVAN_CHAIN_ID = 42;
    
    constructor() {
        
        _setupRole(ROLE_ADMIN, _msgSender());
        _setupRole(ROLE_ADMIN, 0x1EE133d3CC3fD5795DD4014579A36A6b7900102e); // NoBotsTechV3 Deft
        markAddressAsHuman(0x1EE133d3CC3fD5795DD4014579A36A6b7900102e, true); // NoBotsTechV3 Deft
        
        _setupRole(ROLE_ADMIN, 0xDef1Fafc79CD01Cf6797B9d7F51411beF486262a); // Staking Contract
        _setupRole(ROLE_ADMIN, 0x1d2900622B5049D9479DC8BE06469A4ede3Fc96e); // Cross Chain Bridge Contract
        _setupRole(ROLE_ADMIN, 0x9980a0447456b5cdce209D7dC94820FF15600022); // Deft blacklister
        
        markAddressAsBot(0xC25e850F6cedE52809014d4eeCCA402eb47bDC28); // top1 eth bot

        
        markAddressAsHuman(0xDef1Fafc79CD01Cf6797B9d7F51411beF486262a, true); // Staking contract
        markAddressAsHuman(0xdEF78a28c78A461598d948bc0c689ce88f812AD8, true); // Cross Chain Bridge Wallet
        markAddressAsHuman(0xDef1C0ded9bec7F1a1670819833240f027b25EfF, true); // 0x: Exchange Proxy
        markAddressAsHuman(0x11111112542D85B3EF69AE05771c2dCCff4fAa26, true); // 1inch Router
        markAddressAsHuman(0x27239549DD40E1D60F5B80B0C4196923745B1FD2, true); // 1inch Helper
        markAddressAsHuman(0xDEF1fAE3A7713173C168945b8704D4600B6Fc7B9, true); // TeamVestingContract
        markAddressAsHuman(0xdef1fac7Bf08f173D286BbBDcBeeADe695129840, true); // DefiFactoryContract
        markAddressAsHuman(0x881D40237659C251811CEC9c364ef91dC08D300C, true); // Metamask Swap Router
        markAddressAsHuman(0x74de5d4FCbf63E00296fd95d33236B9794016631, true); // metamask router wallet
        markAddressAsHuman(0xe122d2E14d35d794C977b4d6924232CAe7c8DbB5, true); // metamask fees
        
            
        if (block.chainid == ETH_MAINNET_CHAIN_ID)
        {
            markAddressAsHuman(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, true); // uniswap router v2
            markAddressAsHuman(0xE592427A0AEce92De3Edee1F18E0157C05861564, true); // uniswap router v3
            
            markAsUniswapPair(0xFa6687922BF40FF51Bcd45F9FD339215a4869D82, true); // [deft, weth] uniswap v2 pair
            markAsUniswapPair(0x81489b0E7c7A515799C89374E23ac9295088551d, true); // [deft, usdc] uniswap v3 pair
        } else if (block.chainid == BSC_MAINNET_CHAIN_ID)
        {
            markAddressAsHuman(0x10ED43C718714eb63d5aA57B78B54704E256024E, true); // pancake router v2
            
            markAsUniswapPair(0x077324B361272dde2D757f8Ec6Eb59daAe794519, true); // [deft, wbnb] pancake pair
            markAsUniswapPair(0x493E990CcC67F59A3000EfFA9d5b1417D54B6f99, true); // [deft, busd] pancake pair
        } else if (block.chainid == POLYGON_MAINNET_CHAIN_ID)
        {
            markAddressAsHuman(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff, true); // quick router v2
            
            markAsUniswapPair(0x3bcb4ED7132E2f1B7b0fa9966663F24b8210f8b6, true); // [deft, wmatic] quick pair
            markAsUniswapPair(0xF92b726b10956ff95EbABDd6fd92d180d1e920DA, true); // [deft, usdc] quick pair
        }
    }
    
    function getCooldownPeriodSell(address tokenAddr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint)
    {
        return cooldownPeriodSellStorage[tokenAddr] > 0? cooldownPeriodSellStorage[tokenAddr]: DEFAULT_SELL_COOLDOWN;
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
        return isBotStorage[addr] && !isHumanStorage[addr];
    }
    
    function getTransactionInfo(address tokenAddr, address sender, address recipient)
        external
        onlyRole(ROLE_ADMIN)
        returns (TransactionInfo memory output)
    {
        output.isSell = isUniswapPairChecker(recipient);
        output.isBuy = isUniswapPairChecker(sender);
        
        uint defaultSellCooldown = cooldownPeriodSellStorage[tokenAddr] > 0? cooldownPeriodSellStorage[tokenAddr]: DEFAULT_SELL_COOLDOWN;
        if  (
                !output.isBuy && // not Buyer = is Sell or is Transfer
                !isHumanStorage[sender] && // is not Whitelisted
                ( 
                    isBotStorage[sender] || // is Blacklisted
                    buyTimestampStorage[tokenAddr][sender] + defaultSellCooldown >= block.timestamp // is Selling or Transferring Too Fast
                )
            )
        {
            revert("DS: Transfers are temporary disabled");
        }
        
        return output;
    }
    
    function isUniswapPairChecker(address addr)
        public
        onlyRole(ROLE_ADMIN)
        returns (bool isUni)
    {
        isUni = isUniswapPair[addr];
        if (!isUni)
        {
            bytes memory data = abi.encodeWithSignature("token1()");
            (, data) = address(addr).staticcall(data);
            isUni = data.length > 0;
        }
        
        if (isUni)
        {
            isUniswapPair[addr] = true;
        }
        
        return isUni;
    }
    
    function isContract(address addr)
        private
        view
        returns(bool)
    {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
    
    
    function isMarkedAsUniswapPair(address addr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (bool)
    {
        return isUniswapPair[addr];
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
    
    function markAsUniswapPair(address addr, bool value)
        public
        onlyRole(ROLE_ADMIN)
    {
        isUniswapPair[addr] = value;
    }
    
    function bulkMarkAsUniswapPair(address[] calldata addrs, bool value)
        external
        onlyRole(ROLE_ADMIN)
    {
        for(uint i = 0; i<addrs.length; i++)
        {
            isUniswapPair[addrs[i]] = value;
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