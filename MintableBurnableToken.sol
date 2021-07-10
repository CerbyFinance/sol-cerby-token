// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./openzeppelin/token/ERC20/ERC20.sol";

contract MintableBurnableToken is ERC20 {
    
    address owner;
    constructor()
        ERC20("bscTEST2", "bscTEST2", 18) 
    {
        owner = msg.sender;
        //_mint(msg.sender, 1e18*1e9);
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
}
