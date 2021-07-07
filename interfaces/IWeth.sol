// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;


interface IWeth {

    function balanceOf(
        address account
    )
        external
        view
        returns (uint);
        
    function decimals()
        external
        view
        returns (uint);

    function transfer(
        address _to,
        uint _value
    )  external returns (
        bool success
    );
    
    function mint(address to, uint desiredAmountToMint) 
        external;
    
    function burn(address from, uint desiredAmountBurn) 
        external;
        
    function deposit()
        external
        payable;

    function withdraw(
        uint wad
    ) external;

    function approve(
        address _spender,
        uint _value
    )  external returns (
        bool success
    );
}
