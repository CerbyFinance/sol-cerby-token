// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.11;

struct Pool {
    uint32[8] tradeVolumePerPeriodInCerUsd;
    uint128 balanceToken;
    uint128 balanceCerUsd;
    uint128 lastSqrtKValue;
    uint256 creditCerUsd;
}

interface ICerbySwapV1 {
    function getCurrentFeeBasedOnTrades(address token)
        external
        view
        returns (uint256 fee);

    function getPoolsByTokens(address[] calldata tokens)
        external
        view
        returns (Pool[] memory);

    function addTokenLiquidity(
        address token,
        uint256 amountTokensIn,
        uint256 expireTimestamp,
        address transferTo
    ) external payable returns (uint256);

    function removeTokenLiquidity(
        address token,
        uint256 amountLpTokensBalanceToBurn,
        uint256 expireTimestamp,
        address transferTo
    ) external returns (uint256);

    function swapExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountTokensIn,
        uint256 minAmountTokensOut,
        uint256 expireTimestamp,
        address transferTo
    ) external payable returns (uint256, uint256);

    function getInputTokensForExactTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountTokensOut
    ) external view returns (uint256 amountTokensIn);

    function getOutputExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountTokensIn
    ) external view returns (uint256 amountTokensOut);
}
