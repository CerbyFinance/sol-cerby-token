// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import "./interfaces/IWeth.sol";
import "./interfaces/ICerbyToken.sol";
import "./interfaces/IUniswapV2Pair.sol";

contract CerbyUsdBalancer {

    address constant cerbyToken = 0x06b32Ee69B1e29619c9179F76b55592Fa006Fd2f;
    address constant cerUSDToken = 0xA51aaB4a80d657E2eaC7227E949EA35732938F30;
    address constant uniswapPair = 0xb11a0E1e7c5DFC87dF7B2dC88CC71937CBAC617f;

    uint constant PRICE_DENORM = 1e18;
    uint constant FEE_DENORM = 10000;

    constructor() {
    }

    function balance(uint targetPrice)
        public
    {
        IUniswapV2Pair iPair = IUniswapV2Pair(uniswapPair);
        (uint balanceCerby, uint balanceCerUSD,) = iPair.getReserves();
        if (cerUSDToken > cerbyToken)
        {
            (balanceCerby, balanceCerUsd) = (balanceCerUsd, balanceCerby);
        }
        uint initialPrice = (balanceCerUsd * DENORM) / balanceCerby;

        uint sqrtMagic = (sqrt((balanceCerby * balanceCerUSD * targetPrice) / DENORM);
        if (targetPrice > initialPrice)
        {
            uint sellCerUSD = (sqrtMagic - balanceCerUsd) * FEE_DENORM) / getFee();
        } else if (targetPrice < initialPrice)
        {
            uint buyCerUSD = sqrtMagic + balanceCerUsd;
        }
    }


    function doSwap(bool isBuy, uint amountToTrade)
        public
        returns (uint)
    {
        address tokenFrom = isBuy? cerUSDToken  : cerbyToken;
        address tokenTo = isBuy? cerbyToken: cerUSDToken;
        
        IWeth(tokenFrom).transfer(uniswapPair, amountToTrade);
        
        (uint reserveIn, uint reserveOut,) = IUniswapV2Pair(uniswapPair).getReserves();
        if (tokenFrom > tokenTo)
        {
            (reserveIn, reserveOut) = (reserveOut, reserveIn);
        }
        
        uint amountInWithFee = amountToTrade * getFee();
        uint amountOut = (amountInWithFee * reserveOut) / (reserveIn * FEE_DENORM + amountInWithFee);
        
        (uint amount0Out, uint amount1Out) = tokenFrom > tokenTo? 
            (amountOut, uint(0)): (uint(0), amountOut);
        
        IUniswapV2Pair(uniswapPair).swap(
            amount0Out, 
            amount1Out, 
            address(this), 
            new bytes(0)
        );
        
        return amountOut;
    }

    function sqrt(uint y) internal pure returns (uint z) 
    {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function getFee() {
        private
        returns(uint)
    {
        return 9970;
    }
}