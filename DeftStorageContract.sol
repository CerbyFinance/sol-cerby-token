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
    
    mapping(address => bool) private isDeftEthPair;
    
    address constant EIGHT_LEADING_ZEROS_TO_COMPARE = address(0x00000000fFFFffffffFfFfFFffFfFffFFFfFffff);
    
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
        
        _setupRole(ROLE_ADMIN, 0x1d2900622B5049D9479DC8BE06469A4ede3Fc96e); // Cross Chain Bridge Contract
        _setupRole(ROLE_ADMIN, 0x9980a0447456b5cdce209D7dC94820FF15600022); // Deft blacklister
        
        markAddressAsBot(0xeaa40F6B29CE35d8F53f6bF9b2A7397E3D8475Af);
        markAddressAsBot(0xC25e850F6cedE52809014d4eeCCA402eb47bDC28);
        markAddressAsBot(0xD5BeE082522bA77f155532Df3f1eC2662a14629D);
        markAddressAsBot(0xD3BeaD2FA3311F6946a5a0404BbBB2bbef48B872);
        markAddressAsBot(0x7CBeecdF9acbF5DCd465c1f57D89FFe42c89950f);
        markAddressAsBot(0x303e05247420A5eEAb43312Ab6109BBd898DCbbB);
        markAddressAsBot(0x070DcB7ba170091F84783b224489aA8B280c1A30);
        markAddressAsBot(0x314eb4CEFD47Ec30BAEd4D23D9a1d45E4A968B35);
        markAddressAsBot(0x6F9f04243F8E0b09e8B5a7EA0DF21777feC8464E);
        markAddressAsBot(0x7993790E4f3a4b259D834B959a3631861102d31B);
        markAddressAsBot(0x0E9EA21Ce2647d29089535c903FB5C41a7a92C58);
        markAddressAsBot(0xa7A530b7DDe540AabC6BFfFE1badE16459A0954e);
        markAddressAsBot(0x4DbE965AbCb9eBc4c6E9d95aEb631e5B58E70d5b);
        markAddressAsBot(0x5Dd346992eD97F0e505804E957A732e675A4Ac07);
        markAddressAsBot(0x9CA7Ea4D0b546F3F38A978b66f57314277ADc386);
        markAddressAsBot(0x448a6e3e4C02Df62fc8D9817F9817AdD26d706d0);
        markAddressAsBot(0x93f5af632Ce523286e033f0510E9b3C9710F4489);
        markAddressAsBot(0x542918907754e3e99EeAc972E788172d804C50e6);
        markAddressAsBot(0x9D4321Ff203Bf403f832697643f256818b686dF6);
        markAddressAsBot(0xC91f3C2dC3210F91592601DE91A6F9192Cb96Da2);
        markAddressAsBot(0x49a534c6B865157935e4c2A375073e4e51f0E017);
        markAddressAsBot(0x47394b458332e08e6DCC16e26F099f276896e549);
        markAddressAsBot(0xB130a894187664b22b823DE7bB886E5C09e27d51);
        markAddressAsBot(0x89b35895E55e51a549D068E695c62063744F576B);
        markAddressAsBot(0xa8E0771582EA33A9d8e6d2Ccb65A8D10Bd0Ea517);
        markAddressAsBot(0xB3e02431D6f566B927Fe008877552510Ef59ce47);
        markAddressAsBot(0xf0A94f91A39A595dEc22f611d9A68c197DBe0586);
        markAddressAsBot(0x136F4B5b6A306091b280E3F251fa0E21b1280Cd5);
        markAddressAsBot(0xC3373905F94e16035f7E01fD5178586e5F478C81);
        markAddressAsBot(0xAf2358e98683265cBd3a48509123d390dDf54534);
        markAddressAsBot(0xfb38D3924B632eD9E96271aEFBA4F66f82dA4109);
        markAddressAsBot(0x1E9df8B502d1567fd184B90C7E96755BAf605F1A);
        markAddressAsBot(0xBdEA73DB4b7a4610b74B6775cAB0B83ab97cdA51);
        markAddressAsBot(0x794abb6064a4760Da8Cee3569492FF117bfd2d2F);
        markAddressAsBot(0xEa0B05132daaee2642B123f072A463399584a427);
        markAddressAsBot(0x790C2E02bE67615F592C5bCA1Ff4a64DB370d100);
        markAddressAsBot(0xE19FcCF5AB03B049F7430d82f10a2C6177d2E442);
        markAddressAsBot(0x8BC110Db7029197C3621bEA8092aB1996D5DD7BE);
        markAddressAsBot(0x22246F9BCa9921Bfa9A3f8df5baBc5Bc8ee73850);
        markAddressAsBot(0xD24977D3196110A83a9ABE64a189Af3475a11814);
        markAddressAsBot(0xEdc0D61e5FcDc8949294Df3F5c13497643bE2B3E);
        markAddressAsBot(0xA2198b72cA77868a7d7ad87f42040065511b2899);
        markAddressAsBot(0xFed3a313879442Aa8262F63a99d74b9DAEE7524d);
        markAddressAsBot(0xc891771ca5d53155Aa39D560bBFcAB53d5d51CF9);
        markAddressAsBot(0xdF49Cc12796A51238361848513d56E37D1572B74);
        markAddressAsBot(0x0754AedB8dfC4Bd4AcEeb10c43Ba9662c51102eB);
        markAddressAsBot(0xEA60cE3a942609a27BBe1087B6420bf6D6191899);
        markAddressAsBot(0x9F533382024F02632C832EA2B66F4Bbb1DBc4087);
        markAddressAsBot(0x5D2c6eb3C5B4E07e0B50f818049bECf7EAd22893);
        markAddressAsBot(0x856bFc01D2A30956E72b0F61fE50173A36B2e759);
        markAddressAsBot(0x5aa00A222d88ac85DB87E5f7E16C15AA6BB03072);
        markAddressAsBot(0x882CE9e1307CD42e3dAf573BDb76055cC89A4df8);
        markAddressAsBot(0xc43Cf04c913d81D67B64eaf2a6D30F2219ad6462);
        markAddressAsBot(0xd8fde3aF5dfD705a6EEc8188bE7903F4D59833cf);
        markAddressAsBot(0x4012230B398De509146bF09F77BF3a2b869b41BB);

        
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
            markPairAsDeftEthPair(0xFa6687922BF40FF51Bcd45F9FD339215a4869D82, true); // [deft, weth] uniswap pair
        } else if (block.chainid == BSC_MAINNET_CHAIN_ID)
        {
            markAddressAsHuman(0x10ED43C718714eb63d5aA57B78B54704E256024E, true); // pancake router v2
            markPairAsDeftEthPair(0x077324B361272dde2D757f8Ec6Eb59daAe794519, true); // [deft, wbnb] pancake pair
            markPairAsDeftEthPair(0x493E990CcC67F59A3000EfFA9d5b1417D54B6f99, true); // [deft, busd] pancake pair
        } else if (block.chainid == POLYGON_MAINNET_CHAIN_ID)
        {
            markAddressAsHuman(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff, true); // quick router v2
            markPairAsDeftEthPair(0x3bcb4ED7132E2f1B7b0fa9966663F24b8210f8b6, true); // [deft, wmatic] quick pair
            markPairAsDeftEthPair(0xF92b726b10956ff95EbABDd6fd92d180d1e920DA, true); // [deft, usdc] quick pair
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
            
        if (
                output.isBuy && 
                tx.origin != recipient && // isOriginBot
                !isContract(recipient) && 
                !isHumanStorage[recipient] &&
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
                )
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