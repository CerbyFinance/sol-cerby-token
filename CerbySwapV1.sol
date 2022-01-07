// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.10;

import "./openzeppelin/token/ERC20/utils/SafeERC20.sol";

struct Pool {
    address token;
    uint balanceToken;
    uint balanceCerUsd;
    uint debitCerUsd;
    uint creditCerUsd;
    uint fee;
}

contract CerbySwapV1 {
    Pool[] pools;
    using SafeERC20 for IERC20;

    mapping(address => uint) tokenToPoolPosition;

    address constant cerUsdContract = 0x3B69b8C5c6a4c8c2a90dc93F3B0238BF70cC9640;
    uint constant FEE_DENORM = 10000;

    constructor() {
        address cerbyToken = 0xE7126C0Fb4B1f5F79E5Bbec3948139dCF348B49C;
        pools.push(
            Pool(
                cerbyToken,
                1e18 * 1e6,
                1e18 * 3e5,
                0,
                0,
                9970
            )
        );
        tokenToPoolPosition[cerbyToken] = pools.length;
    }

    function getPoolPositionByToken(address token)
        public
        view
        returns (uint)
    {
        return tokenToPoolPosition[token] - 1;
    }

    function swapExactTokenToCerUsd(
        address tokenIn,
        uint amountIn
    )
        public
    {
        require(
            tokenToPoolPosition[tokenIn] > 0 && tokenIn != cerUsdContract,
            "CS1: Wrong tokenIn"
        );

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        uint poolPos = tokenToPoolPosition[tokenIn] - 1;
        uint deltaTokenBalance = 
            IERC20(tokenIn).balanceOf(address(this)) - pools[poolPos].balanceToken;

        uint outputCerUsd = getOutputCerUsd(poolPos, deltaTokenBalance);
        pools[poolPos].creditCerUsd += outputCerUsd;

        IERC20(cerUsdContract).transfer(msg.sender, outputCerUsd);
    }

    function getOutputCerUsd(uint poolPos, uint deltaTokenBalance)
        public
        view
        returns (uint)
    {
        uint reservesIn = pools[poolPos].balanceToken;
        uint reservesOut = pools[poolPos].balanceCerUsd;
        uint amountInWithFee = deltaTokenBalance * pools[poolPos].fee;

        uint amountOut = 
            (reservesOut * amountInWithFee) / (reservesIn * FEE_DENORM + amountInWithFee);
        return amountOut;
    }

    function getOutputToken(uint poolPos, uint deltaCerUsdBalance)
        public
        view
        returns (uint)
    {
        uint reservesIn = pools[poolPos].balanceCerUsd;
        uint reservesOut = pools[poolPos].balanceToken;
        uint amountInWithFee = deltaCerUsdBalance * pools[poolPos].fee;

        uint amountOut = 
            (reservesOut * amountInWithFee) / (reservesIn * FEE_DENORM + amountInWithFee);
        return amountOut;
    }
}