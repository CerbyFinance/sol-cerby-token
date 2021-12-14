// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import "./interfaces/IWeth.sol";
import "./interfaces/ICerbyToken.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapV2Factory.sol";

contract CerbyUsdBalancer {

    address constant cerbyToken = 0x0d0B2fE71077696Dc60b884e6A4A1a0Ec8e81387;
    address constant cerUSDToken = 0x84e6A4d6F51EAb4Ebddaa791a25578E2103Bb52f;
    address uniswapPair;
    address constant UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    

    uint constant PRICE_DENORM = 1e18;
    uint constant FEE_DENORM = 10000;

    uint constant PERCENTAGE_INCREASE = 1005;
    uint constant PERCENTAGE_DECREASE = 995;
    uint constant PERCENTAGE_DENORM = 1000;

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

    function balance(uint targetPrice)
        public
    {
        uint B;
        uint C;
        uint balanceCerby;
        uint balanceCerUSD;
        uint initialPrice;
        IUniswapV2Router iRouter = IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS);

        (balanceCerUSD, balanceCerby, initialPrice) = getPrice();
        if ((targetPrice * PERCENTAGE_INCREASE) / PERCENTAGE_DENORM > initialPrice)
        {
            B = balanceCerUSD / 2 + (balanceCerUSD * FEE_DENORM) / (2 * getFee());
            C = (balanceCerby * balanceCerUSD * targetPrice * FEE_DENORM) / (PRICE_DENORM * getFee()) -
                    (balanceCerUSD * balanceCerUSD * FEE_DENORM) / getFee();

            uint sellCerUSD = sqrt(B * B + C) - B;
            ICerbyToken(cerUSDToken).mintHumanAddress(address(this), sellCerUSD);

            doSwap(true, sellCerUSD);

            uint cerbyContractBalance = IWeth(cerbyToken).balanceOf(address(this));

            uint addLiquidityCerUSD = (cerbyContractBalance * targetPrice) / (PRICE_DENORM);
            ICerbyToken(cerUSDToken).mintHumanAddress(address(this), addLiquidityCerUSD);

            iRouter.addLiquidity(
                cerUSDToken,
                cerbyToken,
                addLiquidityCerUSD,
                cerbyContractBalance,
                0,
                0,
                address(this),
                block.timestamp + 86400
            );

            uint cerUsdDust = ICerbyToken(cerUSDToken).balanceOf(address(this));
            if (cerUsdDust > 1e16)
            {
                ICerbyToken(cerUSDToken).burnHumanAddress(address(this), cerUsdDust);
            }
        } else if ((targetPrice * PERCENTAGE_DECREASE) / PERCENTAGE_DENORM < initialPrice)
        {
            removeLiquidity((PERCENTAGE_DENORM * 999) / 1000);
            
            (balanceCerUSD, balanceCerby,) = getPrice();
            B = balanceCerby / 2 + (balanceCerby * FEE_DENORM) / (2 * getFee());
            C = (balanceCerby * balanceCerUSD * PRICE_DENORM * FEE_DENORM) / (targetPrice * getFee()) -
                    (balanceCerby * balanceCerby * FEE_DENORM) / getFee();

            uint sellCerby = sqrt(B * B + C) - B;
            
            doSwap(false, sellCerby);

            uint cerbyContractBalance = IWeth(cerbyToken).balanceOf(address(this));

            uint addLiquidityCerUSD = (cerbyContractBalance * targetPrice) / (PRICE_DENORM);
            iRouter.addLiquidity(
                cerUSDToken,
                cerbyToken,
                addLiquidityCerUSD,
                cerbyContractBalance,
                0,
                0,
                address(this),
                block.timestamp + 86400
            );

            uint cerUsdDust = ICerbyToken(cerUSDToken).balanceOf(address(this));
            if (cerUsdDust > 1e16)
            {
                ICerbyToken(cerUSDToken).burnHumanAddress(address(this), cerUsdDust);
            }
        }
    }

    function test123()
        public
        returns(uint)
    {
        return 123;
    }

    function getPrice()
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

    function removeLiquidity(uint percent)
        public
    {
        uint lpTokensBalance = 
            (IWeth(uniswapPair).balanceOf(address(this)) * percent) / PERCENTAGE_DENORM;
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
        removeLiquidity(PERCENTAGE_DENORM);

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