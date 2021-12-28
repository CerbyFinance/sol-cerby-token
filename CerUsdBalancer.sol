// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import "./interfaces/IWeth.sol";
import "./interfaces/ICerbyToken.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV3Pool.sol";

contract CerbyUsdBalancer {

    address constant cerbyToken = 0xC1d02bc2535BCB52BDAA02623BE2a829bd60b099;
    address constant cerUSDToken = 0x18De814Cd95ECc725E3b04911265A790483aC126;
    address constant USDCToken = 0x44a354d3e9C5916aB47143E2739BB6448821D447;
    address uniswapPairCerbyCerUSD;
    address uniswapPairCerbyUSDC;
    address constant UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    

    uint constant PRICE_DENORM = 1e18;
    uint constant FEE_DENORM = 10000;
    uint constant UNISWAP_V3_FEE = 3000;

    uint constant PERCENTAGE_INCREASE = 1005;
    uint constant PERCENTAGE_DECREASE = 995;
    uint constant PERCENTAGE_DENORM = 1000;

    uint lastBalancedAt = block.timestamp;
    uint secondsBetweenBalancing = 1;

    address[] pathBuyCerbyCerUSD = new address[](2);
    address[] pathSellCerbyCerUSD = new address[](2);
    address[] pathBuyCerbyUSDC = new address[](2);
    address[] pathSellCerbyUSDC = new address[](2);

    constructor() {
        pathSellCerbyCerUSD[0] = cerbyToken;
        pathSellCerbyCerUSD[1] = cerUSDToken;
        pathBuyCerbyCerUSD[0] = cerUSDToken;
        pathBuyCerbyCerUSD[1] = cerbyToken;

        pathSellCerbyUSDC[0] = cerbyToken;
        pathSellCerbyUSDC[1] = USDCToken;
        pathBuyCerbyUSDC[0] = USDCToken;
        pathBuyCerbyUSDC[1] = cerbyToken;

        IWeth(cerbyToken).approve(UNISWAP_V2_ROUTER_ADDRESS, type(uint).max);
        IWeth(cerUSDToken).approve(UNISWAP_V2_ROUTER_ADDRESS, type(uint).max);
        IWeth(USDCToken).approve(UNISWAP_V2_ROUTER_ADDRESS, type(uint).max); 

        uniswapPairCerbyCerUSD = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).getPair(cerUSDToken, cerbyToken);
        if (address(0x0) == uniswapPairCerbyCerUSD)
        {
            uniswapPairCerbyCerUSD = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).createPair(cerUSDToken, cerbyToken);            
        }

        uniswapPairCerbyUSDC = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).getPair(USDCToken, cerbyToken);
        if (address(0x0) == uniswapPairCerbyUSDC)
        {
            uniswapPairCerbyUSDC = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).createPair(USDCToken, cerbyToken);            
        }  
        IWeth(uniswapPairCerbyCerUSD).approve(UNISWAP_V2_ROUTER_ADDRESS, type(uint).max);
        IWeth(uniswapPairCerbyUSDC).approve(UNISWAP_V2_ROUTER_ADDRESS, type(uint).max);     
    }

    function balance()
        public
    {
        if (lastBalancedAt + secondsBetweenBalancing > block.timestamp) return;

        uint B;
        uint C;
        uint balanceCerby;
        uint balanceCerUSD;
        uint balanceCerbyTarget;
        uint balanceUSDC;
        uint initialPrice;
        uint targetPrice;

        (balanceUSDC, balanceCerbyTarget, targetPrice) = getPriceCerbyUSDC();
        (balanceCerUSD, balanceCerby, initialPrice) = getPriceCerbyCerUSD();

        if (targetPrice * PERCENTAGE_DECREASE  > initialPrice * PERCENTAGE_DENORM)
        {
            B = balanceCerUSD / 2 + (balanceCerUSD * FEE_DENORM) / (2 * getFee());
            C = (balanceCerby * balanceCerUSD * targetPrice * FEE_DENORM) / (PRICE_DENORM * getFee()) -
                    (balanceCerUSD * balanceCerUSD * FEE_DENORM) / getFee();

            uint sellCerUSD = sqrt(B * B + C) - B;
            ICerbyToken(cerUSDToken).mintHumanAddress(address(this), sellCerUSD);

            doSwapCerbyCerUSD(true, sellCerUSD, false);

            uint cerbyContractBalance = IWeth(cerbyToken).balanceOf(address(this));

            uint addLiquidityCerUSD = (cerbyContractBalance * targetPrice) / (PRICE_DENORM);
            ICerbyToken(cerUSDToken).mintHumanAddress(address(this), addLiquidityCerUSD);

            IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS).addLiquidity(
                cerUSDToken,
                cerbyToken,
                addLiquidityCerUSD,
                cerbyContractBalance,
                0,
                0,
                address(this),
                block.timestamp + 86400
            );

            makeCerbyTokensInBothPoolsEqual();
            removeCerUsdDust();
        } else if (targetPrice * PERCENTAGE_INCREASE < initialPrice * PERCENTAGE_DENORM)
        {
            removeLiquidity((PERCENTAGE_DENORM * 999) / 1000);
            
            (balanceCerUSD, balanceCerby,) = getPriceCerbyCerUSD();
            B = balanceCerby / 2 + (balanceCerby * FEE_DENORM) / (2 * getFee());
            C = (balanceCerby * balanceCerUSD * PRICE_DENORM * FEE_DENORM) / (targetPrice * getFee()) -
                    (balanceCerby * balanceCerby * FEE_DENORM) / getFee();

            uint sellCerby = sqrt(B * B + C) - B;
            
            doSwapCerbyCerUSD(false, sellCerby, false);

            uint cerbyContractBalance = IWeth(cerbyToken).balanceOf(address(this));

            uint addLiquidityCerUSD = (cerbyContractBalance * targetPrice) / (PRICE_DENORM);
            IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS).addLiquidity(
                cerUSDToken,
                cerbyToken,
                addLiquidityCerUSD,
                cerbyContractBalance,
                0,
                0,
                address(this),
                block.timestamp + 86400
            );

            makeCerbyTokensInBothPoolsEqual();
            removeCerUsdDust();
        }

        lastBalancedAt = block.timestamp;
    }

    function removeCerUsdDust()
        public
    {
        uint cerUsdDust = ICerbyToken(cerUSDToken).balanceOf(address(this));
        if (cerUsdDust > 1e16)
        {
            ICerbyToken(cerUSDToken).burnHumanAddress(address(this), cerUsdDust);
        }
    }

    function makeCerbyTokensInBothPoolsEqual()
        public
    {
        (, uint balanceCerbyTarget,) = getPriceCerbyUSDC();
        (uint balanceCerUSD, uint balanceCerby,) = getPriceCerbyCerUSD();
        if (balanceCerby > balanceCerbyTarget)
        {
            uint difference = balanceCerby - balanceCerbyTarget;
            uint lpSupply = ICerbyToken(uniswapPairCerbyCerUSD).totalSupply();

            uint lpToRemove = (difference * lpSupply) / balanceCerby;
            IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS).removeLiquidity(
                cerUSDToken,
                cerbyToken,
                lpToRemove,
                0,
                0,
                address(this),
                block.timestamp + 86400
            );
        } else if (balanceCerby < balanceCerbyTarget)
        {
            uint difference = balanceCerbyTarget - balanceCerby;
            ICerbyToken(cerbyToken).mintHumanAddress(address(this), difference);

            uint cerUsdToMint = (difference * balanceCerUSD) / balanceCerby;
            ICerbyToken(cerUSDToken).mintHumanAddress(address(this), cerUsdToMint);

            IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS).addLiquidity(
                cerUSDToken,
                cerbyToken,
                cerUsdToMint,
                difference,
                0,
                0,
                address(this),
                block.timestamp + 86400
            );
        }
    }

    function getPriceCerbyCerUSD()
        public
        view
        returns (uint, uint, uint)
    {
        IUniswapV2Pair iPair = IUniswapV2Pair(uniswapPairCerbyCerUSD);
        (uint balanceCerby, uint balanceCerUSD,) = iPair.getReserves();
        if (cerbyToken > cerUSDToken)
        {
            (balanceCerby, balanceCerUSD) = (balanceCerUSD, balanceCerby);
        }
        uint initialPrice = (balanceCerUSD * PRICE_DENORM) / balanceCerby;
        return (balanceCerUSD, balanceCerby, initialPrice);
    }

    function getPriceCerbyUSDC()
        public
        view
        returns (uint, uint, uint)
    {
        IUniswapV2Pair iPair = IUniswapV2Pair(uniswapPairCerbyUSDC);
        (uint balanceCerby, uint balanceUSDC,) = iPair.getReserves();
        if (cerbyToken > USDCToken)
        {
            (balanceCerby, balanceUSDC) = (balanceUSDC, balanceCerby);
        }
        uint initialPrice = (balanceUSDC * PRICE_DENORM) / balanceCerby;
        return (balanceUSDC, balanceCerby, initialPrice);
    }

    function removeLiquidity(uint percent)
        public
    {
        uint lpTokensBalance = 
            (IWeth(uniswapPairCerbyCerUSD).balanceOf(address(this)) * percent) / PERCENTAGE_DENORM;
        if (lpTokensBalance > 0)
        {
            IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS).removeLiquidity(
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
        uint addLiquidityCerUSD = 1e18 * 300000000;
        ICerbyToken(cerUSDToken).mintHumanAddress(address(this), addLiquidityCerUSD);
        ICerbyToken(USDCToken).mintHumanAddress(address(this), addLiquidityCerUSD);

        uint addLiquidityCerby = 1e18 * 1000000000;
        ICerbyToken(cerbyToken).mintHumanAddress(address(this), 2 * addLiquidityCerby);

        IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS).addLiquidity(
            cerUSDToken,
            cerbyToken,
            addLiquidityCerUSD,
            addLiquidityCerby,
            0,
            0,
            address(this),
            block.timestamp + 86400
        );
        IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS).addLiquidity(
            USDCToken,
            cerbyToken,
            addLiquidityCerUSD,
            addLiquidityCerby,
            0,
            0,
            address(this),
            block.timestamp + 86400
        );
    }

    function doSwapCerbyCerUSD(bool isBuy, uint amountIn, bool isMint)
        public
        returns(uint)
    {
        address[] memory path = isBuy? pathBuyCerbyCerUSD: pathSellCerbyCerUSD;
        
        if (isMint)
        {
            ICerbyToken(path[0]).mintHumanAddress(address(this), amountIn);
        }
        uint[] memory amounts = IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS).swapExactTokensForTokens(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp + 86400
        );        
        
        return amounts[amounts.length-1];
    }

    function doSwapCerbyUSDC(bool isBuy, uint amountIn, bool isMint)
        public
        returns(uint)
    {
        address[] memory path = isBuy? pathBuyCerbyUSDC: pathSellCerbyUSDC;
        
        if (isMint)
        {
            ICerbyToken(path[0]).mintHumanAddress(address(this), amountIn);
        }
        uint[] memory amounts = IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS).swapExactTokensForTokens(
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