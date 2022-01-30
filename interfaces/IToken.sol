// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IToken {
    function deposit() external payable;

    function withdraw(uint256 wad) external;

    function balanceOf(address account) external view returns (uint256);

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

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address);

    function transfer(address _to, uint256 _value)
        external
        returns (bool success);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function getBalance(address token) external view returns (uint256);

    function getSwapFee() external view returns (uint256);

    function getDenormalizedWeight(address token)
        external
        view
        returns (uint256);

    function getCurrentTokens() external view returns (address[] memory);
}
