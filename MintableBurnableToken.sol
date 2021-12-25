// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./openzeppelin/token/ERC20/ERC20.sol";

contract MintableBurnableToken is ERC20 {
    
    address owner;
    constructor()
        //ERC20("CERBY", "CERBY", 18)
        //ERC20("cerUSD", "cerUSD", 18)
        ERC20("USDC", "USDC", 18)
    {
        owner = msg.sender;
        _mint(0xDc15Ca882F975c33D8f20AB3669D27195B8D87a6, 1e18*1e9);
        _mint(0x539FaA851D86781009EC30dF437D794bCd090c8F, 1e18*1e9);
    }
    
    function mintByBridge(address to, uint amount) public {
        _mint(to, amount);
    }
    
    function burnByBridge(address from, uint amount) public {
        _burn(from, amount);
    }
    
    function mintHumanAddress(address to, uint amount) public {
        //require(msg.sender == owner);
        _mint(to, amount);
    }
    
    function burnHumanAddress(address from, uint amount) public {
        //require(msg.sender == owner);
        _burn(from, amount);
    }
    
    function transferCustom(address sender, address recipient, uint256 amount)
        external
    {
        _transfer(sender, recipient, amount);
    }
}
