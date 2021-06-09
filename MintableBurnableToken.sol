// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./openzeppelin/token/ERC20/ERC20.sol";

contract MintableBurnableToken is ERC20 {
    
    constructor()
        ERC20("Mintable", "MNT", 18) 
    {
        _mint(msg.sender, 1e18*1e9);
    }
    
    function mintByBridge(address to, uint amount) public {
        _mint(to, amount);
    }
    
    function burnByBridge(address from, uint amount) public {
        _burn(from, amount);
    }
}
