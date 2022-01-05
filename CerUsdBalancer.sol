// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import "./interfaces/IWeth.sol";
import "./interfaces/ICerbyToken.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";

contract CerbyUsdBalancer is AccessControlEnumerable {

    address constant cerbyToken = 0xC1d02bc2535BCB52BDAA02623BE2a829bd60b099; // TODO: update
    address constant cerUSDToken = 0x18De814Cd95ECc725E3b04911265A790483aC126; // TODO: update
    address USDCToken;
    address uniswapPairCerbyCerUSD;
    address uniswapPairCerbyUSDC;
    address UNISWAP_V2_ROUTER_ADDRESS;
    uint fee;
    

    uint constant PRICE_DENORM = 1e18;
    uint constant FEE_DENORM = 10000;
    uint constant UNISWAP_V3_FEE = 3000;

    uint constant PERCENTAGE_INCREASE = 1005;
    uint constant PERCENTAGE_DECREASE = 995;
    uint constant PERCENTAGE_DENORM = 1000;

    uint lastBalancedAt = block.timestamp;
    uint secondsBetweenBalancing = 0;

    constructor() {
        if (block.chainid == 1)
        {
            UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
            USDCToken = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
            uniswapPairCerbyCerUSD; // TODO: update
            uniswapPairCerbyUSDC = 0x3Ba90CD69Eb24D439e3DA69024C5dB9894311536;
            fee = 9970;
        } else if (block.chainid == 56)
        {
            UNISWAP_V2_ROUTER_ADDRESS = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
            USDCToken = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
            uniswapPairCerbyCerUSD; // TODO: update
            uniswapPairCerbyUSDC = 0x493E990CcC67F59A3000EfFA9d5b1417D54B6f99;
            fee = 9975;
        } else if (block.chainid == 137)
        {
            UNISWAP_V2_ROUTER_ADDRESS = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
            USDCToken = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
            uniswapPairCerbyCerUSD; // TODO: update
            uniswapPairCerbyUSDC = 0xF92b726b10956ff95EbABDd6fd92d180d1e920DA;
            fee = 9970;
        } else if (block.chainid == 43114)
        {
            UNISWAP_V2_ROUTER_ADDRESS = 0x60aE616a2155Ee3d9A68541Ba4544862310933d4;
            USDCToken = 0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664;
            uniswapPairCerbyCerUSD; // TODO: update
            uniswapPairCerbyUSDC = 0x4e2D00526Ae280D5aa296c321A8d32CD2486A737;
            fee = 9970;
        } else if (block.chainid == 250)
        {
            UNISWAP_V2_ROUTER_ADDRESS = 0xF491e7B69E4244ad4002BC14e878a34207E38c29;
            USDCToken = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
            uniswapPairCerbyCerUSD; // TODO: update
            uniswapPairCerbyUSDC = 0xD450c27c7024f5813449CA30f0D7c4F9d0a19c77;
            fee = 9980;
        }

        IWeth(cerbyToken).approve(UNISWAP_V2_ROUTER_ADDRESS, type(uint).max);
        IWeth(cerUSDToken).approve(UNISWAP_V2_ROUTER_ADDRESS, type(uint).max);

        IWeth(uniswapPairCerbyCerUSD).approve(UNISWAP_V2_ROUTER_ADDRESS, type(uint).max);
    }

    function balancePrice()
        public
    {
        if (
            tx.gasprice > 0 && 
            lastBalancedAt + secondsBetweenBalancing > block.timestamp
        ) {
            return;
        }

        lastBalancedAt = block.timestamp;

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
            B = balanceCerUSD / 2 + (balanceCerUSD * FEE_DENORM) / (2 * fee);
            C = (balanceCerby * balanceCerUSD * targetPrice * FEE_DENORM) / (PRICE_DENORM * fee) -
                    (balanceCerUSD * balanceCerUSD * FEE_DENORM) / fee;

            uint sellCerUSD = sqrt(B * B + C) - B;
            ICerbyToken(cerUSDToken).mintHumanAddress(address(this), sellCerUSD);

            doSwapCerbyCerUSD(true, sellCerUSD);

            makeCerbyTokensInBothPoolsEqual();
            removeCerUsdDust();
        } else if (targetPrice * PERCENTAGE_INCREASE < initialPrice * PERCENTAGE_DENORM)
        {
            uint lpTokensBalance = 
                (IWeth(uniswapPairCerbyCerUSD).balanceOf(address(this)) * 999) / 1000;
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
            
            (balanceCerUSD, balanceCerby,) = getPriceCerbyCerUSD();
            B = balanceCerby / 2 + (balanceCerby * FEE_DENORM) / (2 * fee);
            C = (balanceCerby * balanceCerUSD * PRICE_DENORM * FEE_DENORM) / (targetPrice * fee) -
                    (balanceCerby * balanceCerby * FEE_DENORM) / fee;

            uint sellCerby = sqrt(B * B + C) - B;
            
            doSwapCerbyCerUSD(false, sellCerby);

            makeCerbyTokensInBothPoolsEqual();
            removeCerUsdDust();
        }
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
        if (balanceCerby * PERCENTAGE_DENORM > balanceCerbyTarget * PERCENTAGE_INCREASE) // >100.5%
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
        } else if (balanceCerby * PERCENTAGE_DENORM < balanceCerbyTarget * PERCENTAGE_DECREASE) // < 99.5%
        {
            uint difference = balanceCerbyTarget - balanceCerby;
            uint currenctCerbyBalanceAvailable = IWeth(cerbyToken).balanceOf(address(this));
            if (currenctCerbyBalanceAvailable == 0) return;

            difference = difference > currenctCerbyBalanceAvailable? currenctCerbyBalanceAvailable: difference;

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
        return getPrice(uniswapPairCerbyCerUSD, cerbyToken, cerUSDToken);
    }    

    function getPriceCerbyUSDC()
        public
        view
        returns (uint, uint, uint)
    {
        return getPrice(uniswapPairCerbyUSDC, cerbyToken, USDCToken);
    }

    function getPrice(address pair, address tokenA, address tokenB)
        private
        view
        returns (uint, uint, uint)
    {
        IUniswapV2Pair iPair = IUniswapV2Pair(pair);
        (uint balanceA, uint balanceB,) = iPair.getReserves();
        if (tokenA > tokenB)
        {
            (balanceA, balanceB) = (balanceB, balanceA);
        }
        uint initialPrice = (balanceB * PRICE_DENORM) / balanceA;
        return (balanceB, balanceA, initialPrice);
    }


    function doSwapCerbyCerUSD(bool isBuy, uint amountIn)
        public
        returns(uint)
    {
        address[] memory path = new address[](2);
        if (isBuy)
        {
            path[0] = cerUSDToken;
            path[1] = cerbyToken;
        }
        else {        
            path[0] = cerbyToken;
            path[1] = cerUSDToken;
        }
        
        uint[] memory amounts = IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS).
            swapExactTokensForTokens(
                amountIn,
                0,
                path,
                address(this),
                block.timestamp + 86400
            );        
        
        return amounts[amounts.length-1];
    }

    function withdrawTokens(address[] calldata tokens)
        onlyRole(ROLE_ADMIN)
        public
    {
        uint tokenBalance;
        
        for (uint i; i<tokens.length; i++)
        {
            tokenBalance = IWeth(tokens[i]).balanceOf(address(this));
            if (tokenBalance > 0)
            {
                IWeth(tokens[i]).transfer(msg.sender, tokenBalance);
            }
        }        
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
}