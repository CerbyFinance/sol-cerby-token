// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.10;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/IWeth.sol";

struct TransactionInfo {
    bool isBuy;
    bool isSell;
}

contract CerbyBotDetection is AccessControlEnumerable {
    
    mapping(address => bool) private isBotStorage;
    mapping(address => bool) private isHumanStorage;
    
    mapping(address => uint) private cooldownPeriodSellStorage;
    
    mapping(address => mapping(address => uint)) private receiveTimestampStorage;
    
    mapping(address => uint) private isUniswapPairStorage;
    
    uint constant IS_UNISWAP_PAIR = 1;
    uint constant IS_NORMAL_WALLET = 2;
    uint constant IS_UNSET_VALUE = 0;
    
    bytes constant TOKEN1_SIGNATURE = abi.encodeWithSignature("token1()");
    
    address constant EIGHT_LEADING_ZEROS_TO_COMPARE = address(0x00000000fFFFffffffFfFfFFffFfFffFFFfFffff);
    address constant STAKING_CONTRACT = address(0xDef1Fafc79CD01Cf6797B9d7F51411beF486262a);
    address constant BURN_ADDRESS = address(0x0);
    uint constant DEFAULT_SELL_COOLDOWN = 5 minutes;
    
    uint constant ETH_MAINNET_CHAIN_ID = 1;
    uint constant BSC_MAINNET_CHAIN_ID = 56;
    uint constant POLYGON_MAINNET_CHAIN_ID = 137;
    
    uint constant BSC_TESTNET_CHAIN_ID = 97;
    uint constant ETH_ROPSTEN_CHAIN_ID = 3;
    uint constant ETH_KOVAN_CHAIN_ID = 42;
    
    constructor() {
        
        _setupRole(ROLE_ADMIN, _msgSender());
        //_setupRole(ROLE_ADMIN, 0x1EE133d3CC3fD5795DD4014579A36A6b7900102e); // NoBotsTechV3 Deft
        
        _setupRole(ROLE_ADMIN, STAKING_CONTRACT); // Staking Contract
        _setupRole(ROLE_ADMIN, 0xA5df69790ba509c511E2A0A31cEEFfecC4d156C7); // Cross Chain Bridge Contract
        _setupRole(ROLE_ADMIN, 0x9980a0447456b5cdce209D7dC94820FF15600022); // Deft blacklister
        _setupRole(ROLE_ADMIN, 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840); // Cerby Token Contract
        
        markAddressAsBot(0xC25e850F6cedE52809014d4eeCCA402eb47bDC28); // Top1 Eth Bot
        markAddressAsBot(0xcefFe5ba89F63E7d4606208093b71Dc5B8468404); // Marketing Wallet
        markAddressAsBot(0x102ad2CF269404dDfDc4adB1Ff26B4767Fb07358); // Scam: https://polygonscan.com/token/0xdef1fac7bf08f173d286bbbdcbeeade695129840?a=0x102ad2cf269404ddfdc4adb1ff26b4767fb07358
        
        
        markAsUniswapPair(0xE68c1d72340aEeFe5Be76eDa63AE2f4bc7514110, IS_UNISWAP_PAIR); // Defi Plaza
        markAddressAsHuman(0xE68c1d72340aEeFe5Be76eDa63AE2f4bc7514110, true); // Defi Plaza
        markAddressAsHuman(0xDef1Fafc79CD01Cf6797B9d7F51411beF486262a, true); // Staking contract
        markAddressAsHuman(0xdEF78a28c78A461598d948bc0c689ce88f812AD8, true); // Cross Chain Bridge Wallet
        markAddressAsHuman(0xDef1C0ded9bec7F1a1670819833240f027b25EfF, true); // 0x: Exchange Proxy
        markAddressAsHuman(0x1111111254fb6c44bAC0beD2854e76F90643097d, true); // 1inch Router
        markAddressAsHuman(0xc590175E458b83680867AFD273527Ff58f74c02b, true); // 1inch Helper1
        markAddressAsHuman(0x3790C9B5A9B9D9AA1c69140a5f01A57c9B868E1e, true); // 1inch Helper2
        markAddressAsHuman(0x2EC255797FEF7669fA243509b7a599121148FFba, true); // 1inch Helper3
        markAddressAsHuman(0x220bdA5c8994804Ac96ebe4DF184d25e5c2196D4, true); // 1inch Helper4
        markAddressAsHuman(0xDEF1fAE3A7713173C168945b8704D4600B6Fc7B9, true); // TeamVestingContract
        markAddressAsHuman(0xdef1fac7Bf08f173D286BbBDcBeeADe695129840, true); // CerbyTokenContract
        markAddressAsHuman(0x881D40237659C251811CEC9c364ef91dC08D300C, true); // Metamask Swap Router
        markAddressAsHuman(0x74de5d4FCbf63E00296fd95d33236B9794016631, true); // Metamask Router Wallet
        markAddressAsHuman(0xe122d2E14d35d794C977b4d6924232CAe7c8DbB5, true); // Metamask Fees Wallet
        
        if (block.chainid == ETH_MAINNET_CHAIN_ID)
        {
            markAddressAsHuman(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, true); // uniswap router v2
            markAddressAsHuman(0xE592427A0AEce92De3Edee1F18E0157C05861564, true); // uniswap router v3
        } else if (block.chainid == BSC_MAINNET_CHAIN_ID)
        {
            markAddressAsHuman(0x10ED43C718714eb63d5aA57B78B54704E256024E, true); // pancake router v2
        } else if (block.chainid == POLYGON_MAINNET_CHAIN_ID)
        {
            markAddressAsHuman(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff, true); // quick router v2
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
    
    function getReceiveTimestamp(address tokenAddr, address addr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint)
    {
        return receiveTimestampStorage[tokenAddr][addr];
    }
    
    function isBotAddress(address addr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (bool)
    {
        return isBotStorage[addr] && !isHumanStorage[addr];
    }
    
    function checkTransactionInfo(
        address tokenAddr, 
        address sender, 
        address recipient, 
        uint recipientBalance, 
        uint transferAmount
    )
        external
        onlyRole(ROLE_ADMIN)
        returns (TransactionInfo memory output)
    {
        output.isSell = isUniswapPairChecker(recipient);
        output.isBuy = isUniswapPairChecker(sender);
        
        uint defaultSellCooldown = cooldownPeriodSellStorage[tokenAddr] > 0? cooldownPeriodSellStorage[tokenAddr]: DEFAULT_SELL_COOLDOWN;
        if (
                output.isBuy && // checking buys
                !output.isSell && // this means exclude when pair sends tokens to other pair => isSell && isBuy
                tx.origin != recipient && // isOriginBot
                !isContract(recipient) && // only checking user wallets
                !isHumanStorage[recipient] && // skipping whitelisted wallets/contracts
                IWeth(tokenAddr).balanceOf(recipient) <= 1  // need to make sure balance was zero before the transfer
                                                            // to avoid blacklisting existing users by malicious actors
            )
        {
            isBotStorage[recipient] = true; // allow user to buy but mark as bot
        } else if (
                !isHumanStorage[sender] && // skipping whitelisted wallets/contracts
                !output.isBuy && // isSell or isTransfer
                (
                    isContract(sender) || // contracts aren't welcome
                    isBotStorage[sender] || // is Blacklisted Sender
                    sender < EIGHT_LEADING_ZEROS_TO_COMPARE || // address starts from 8 zeros
                    receiveTimestampStorage[tokenAddr][sender] + defaultSellCooldown >= block.timestamp 
                            // don't allow instant transfer after receiving
                )
            )
        {
           revert("CBD: Transfers are temporary disabled");
        }
        
        if (
            sender != STAKING_CONTRACT && // hack to allow scraping stakes
            recipient != BURN_ADDRESS
        ) {
            // geometric mean between old and new receive timestamp
            // depending on transferAmount
            receiveTimestampStorage[tokenAddr][recipient] = 
                (block.timestamp * transferAmount + receiveTimestampStorage[tokenAddr][recipient] * recipientBalance) / 
                    (transferAmount + recipientBalance);
        }

        if (!output.isBuy && !output.isSell)
        {
            executeCronJobs();
        }
        
        return output;
    }

    function executeCronJobs()
        private
    {
        // TODO: add here
    }
    
    function isUniswapPairChecker(address addr)
        private
        returns (bool)
    {
        if (isUniswapPairStorage[addr] == IS_UNSET_VALUE)
        {
            (, bytes memory data) = address(addr).staticcall(TOKEN1_SIGNATURE);
        
            if (data.length > 0)
            {
                isUniswapPairStorage[addr] = IS_UNISWAP_PAIR;
            } else
            {
                isUniswapPairStorage[addr] = IS_NORMAL_WALLET;
            }
        }
        
        return isUniswapPairStorage[addr] == IS_UNISWAP_PAIR;
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
    
    function isUniswapPair(address addr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint)
    {
        return isUniswapPairStorage[addr];
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
    
    function markAsUniswapPair(address addr, uint value)
        public
        onlyRole(ROLE_ADMIN)
    {
        isUniswapPairStorage[addr] = value;
    }
    
    function bulkMarkAsUniswapPair(address[] calldata addrs, uint value)
        external
        onlyRole(ROLE_ADMIN)
    {
        for(uint i = 0; i<addrs.length; i++)
        {
            isUniswapPairStorage[addrs[i]] = value;
        }
    }
    
    function markAddressAsBot(address addr)
        public
        onlyRole(ROLE_ADMIN)
    {
        require(
            !isBotStorage[addr],
            "CBD: bot"
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
            "CBD: !bot"
        );
        
        isBotStorage[addr] = false;
    }
}