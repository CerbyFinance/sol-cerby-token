// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IDefiFactoryToken {
    function mintHumanAddress(address to, uint desiredAmountToMint) external;

    function burnHumanAddress(address from, uint desiredAmountToBurn) external;

    function mintByBridge(address to, uint realAmountToMint) external;

    function burnByBridge(address from, uint realAmountBurn) external;
    
    function getUtilsContractAtPos(uint pos)
        external
        view
        returns (address);
        
    function transferFromTeamVestingContract(address recipient, uint256 amount) external;
}