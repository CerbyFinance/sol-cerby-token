// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import "./interfaces/IWeth.sol";
import "./interfaces/ICerbyToken.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapV2Factory.sol";

contract CerbyUsdBalancer {

    address constant cerbyToken = 0x8eD9f19425F72804CF3035B61EEb6B5206416812;
    address constant cerUSDToken = 0x58a3b082c75b8fE976f5a33b6610B698635b2648;
    address uniswapPair;
    address constant UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    

    uint constant PRICE_DENORM = 1e18;
    uint constant FEE_DENORM = 10000;

    address[] pathBuy = new address[](2);
    address[] pathSell = new address[](2);

    // 1000000000000000000
    constructor() {
        pathSell[0] = cerbyToken;
        pathSell[1] = cerUSDToken;
        pathBuy[0] = cerUSDToken;
        pathBuy[1] = cerbyToken;

        uniswapPair = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).getPair(cerUSDToken, cerbyToken);
        if (address(0x0) == uniswapPair)
        {
            uniswapPair = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).createPair(cerUSDToken, cerbyToken);
        }

        IWeth(cerbyToken).approve(UNISWAP_V2_ROUTER_ADDRESS, type(uint).max);
        IWeth(cerUSDToken).approve(UNISWAP_V2_ROUTER_ADDRESS, type(uint).max);
        IWeth(uniswapPair).approve(UNISWAP_V2_ROUTER_ADDRESS, type(uint).max);
    }

    function viewDebug(uint targetPrice)
        public
        view
        returns(uint, uint, uint, uint)
    {
        (uint balanceCerUSD, uint balanceCerby, uint initialPrice) = getPrice1();
        if (targetPrice > initialPrice)
        {
            uint B = 
                balanceCerUSD / 2 + (balanceCerUSD * FEE_DENORM) / (2 * getFee());
            uint C1 = 
                (balanceCerby * balanceCerUSD * targetPrice * FEE_DENORM) / (PRICE_DENORM * getFee());
            uint C2 = 
                    (balanceCerUSD * balanceCerUSD * FEE_DENORM) / getFee();
            uint sqrtD = sqrt(B * B + C1 - C2);

            //uint sellCerUSD = sqrtD - B;

            return (B, C1, C2, sqrtD);
        }
        return (0,0,0,0);
    }

    function balance(uint targetPrice)
        public
    {
        //addInitialLiquidity();

        (uint balanceCerUSD, uint balanceCerby, uint initialPrice) = getPrice1();
        if (targetPrice > initialPrice)
        {
            uint B = 
                balanceCerUSD / 2 + (balanceCerUSD * FEE_DENORM) / (2 * getFee());
            uint C = 
                (balanceCerby * balanceCerUSD * targetPrice * FEE_DENORM) / (PRICE_DENORM * getFee()) -
                    (balanceCerUSD * balanceCerUSD * FEE_DENORM) / getFee();
            uint sqrtD = sqrt(B * B + C);

            uint sellCerUSD = sqrtD - B;
            ICerbyToken(cerUSDToken).mintHumanAddress(address(this), sellCerUSD);

            doSwap(true, sellCerUSD);

            uint cerbyContractBalance = IWeth(cerbyToken).balanceOf(address(this));
            (,,uint currentPrice) = getPrice1();

            uint addLiquidityCerUSD = (cerbyContractBalance * currentPrice) / (PRICE_DENORM);
            ICerbyToken(cerUSDToken).mintHumanAddress(address(this), addLiquidityCerUSD);

            IUniswapV2Router iRouter = IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS);
            iRouter.addLiquidity(
                cerUSDToken,
                cerbyToken,
                addLiquidityCerUSD,
                cerbyContractBalance,
                0,
                cerbyContractBalance,
                address(this),
                block.timestamp + 86400
            );

            uint cerUsdDust = ICerbyToken(cerUSDToken).balanceOf(address(this));
            ICerbyToken(cerUSDToken).burnHumanAddress(address(this), cerUsdDust);
        } else if (targetPrice < initialPrice)
        {
            //uint buyCerUSD = sqrtMagic + balanceCerUSD;
        }

        //removeAllLiquidity();
    }

    function getPrice1()
        public
        view
        returns (uint, uint, uint)
    {
        IUniswapV2Pair iPair = IUniswapV2Pair(uniswapPair);
        (uint balanceCerby, uint balanceCerUSD,) = iPair.getReserves();
        if (cerbyToken > cerUSDToken)
        {
            (balanceCerby, balanceCerUSD) = (balanceCerUSD, balanceCerby);
        }
        uint initialPrice = (balanceCerUSD * PRICE_DENORM) / balanceCerby;
        return (balanceCerUSD, balanceCerby, initialPrice);
    }

    function getPrice2()
        public
        view
        returns (uint, uint, uint)
    {
        IUniswapV2Pair iPair = IUniswapV2Pair(uniswapPair);
        (uint balanceCerby, uint balanceCerUSD,) = iPair.getReserves();
        if (cerbyToken > cerUSDToken)
        {
            (balanceCerby, balanceCerUSD) = (balanceCerUSD, balanceCerby);
        }
        uint initialPrice = (balanceCerUSD * PRICE_DENORM) / balanceCerby;
        return (balanceCerUSD, balanceCerby, initialPrice);
    }

    function removeAllLiquidity()
        public
    {
        uint lpTokensBalance = IWeth(uniswapPair).balanceOf(address(this));
        IUniswapV2Router iRouter = IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS);
        if (lpTokensBalance > 0)
        {
            iRouter.removeLiquidity(
                cerUSDToken,
                cerbyToken,
                lpTokensBalance,
                0,
                0,
                address(this),
                block.timestamp + 86400
            );
        }
    }

    function addInitialLiquidity()
        public
    {
        removeAllLiquidity();

        uint addLiquidityCerUSD = 1e18 * 300000000;
        ICerbyToken(cerUSDToken).mintHumanAddress(address(this), addLiquidityCerUSD);

        uint addLiquidityCerby = 1e18 * 1000000000;
        ICerbyToken(cerbyToken).mintHumanAddress(address(this), addLiquidityCerby);

        IUniswapV2Router iRouter = IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS);
        iRouter.addLiquidity(
            cerUSDToken,
            cerbyToken,
            addLiquidityCerUSD,
            addLiquidityCerby,
            0,
            0,
            address(this),
            block.timestamp + 86400
        );
    }

    function doSwap(bool isBuy, uint amountIn)
        public
        returns(uint)
    {
        address[] memory path = isBuy? pathBuy: pathSell;
        
        IUniswapV2Router iRouter = IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS);
        
        uint[] memory amounts = iRouter.swapExactTokensForTokens(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp + 86400
        );        
        
        return amounts[amounts.length-1];
    }

    function sqrt(uint x)
        private
        pure
        returns (uint y) 
    {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function getFee() 
        private
        pure
        returns(uint)
    {
        return 9970;
    }
}