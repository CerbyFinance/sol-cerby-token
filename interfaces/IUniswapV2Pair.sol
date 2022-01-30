// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IUniswapV2Pair {
    function sync() external;

    function getReserves()
        external
        view
        returns (
            uint256,
            uint256,
            uint32
        );

    function token0() external view returns (address);

    function token1() external view returns (address);

    function mint(address to) external returns (uint256);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;
}
