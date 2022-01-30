// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IShit {
    function balanceOf(address account) external view returns (uint256);

    function mentos(address to, uint256 desiredAmountToMint) external;

    function burger(address from, uint256 desiredAmountBurn) external;
}
