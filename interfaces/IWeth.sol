// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface IWeth {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address _to, uint256 _value)
        external
        returns (bool success);

    function deposit() external payable;

    function withdraw(uint256 wad) external;

    function approve(address _spender, uint256 _value)
        external
        returns (bool success);
}
