// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IUniswapV3Pool {
    
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) 
        external 
        returns (uint256, uint256);
}
