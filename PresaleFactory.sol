// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.7;

import "./PresaleContract.sol";

contract PresaleFactory {
    
    
    
    PresaleContract[] public presaleContracts;
    
    
    /*
0xDc15Ca882F975c33D8f20AB3669D27195B8D87a6
    
[
    ["0x1111BEe701Ef814A2B6A3EDD4B1652cB9cc5aA6f","Development",150000,60,600],
    ["0x2222bEE701Ef814a2B6a3edD4B1652cB9Cc5Aa6F","Marketing",100000,120,1200],
    ["0x3333BeE701EF814A2b6a3edD4B1652cb9Cc5AA6F","Advisors",50000,180,1800]
]

Kovan: ["0x7A7492a8e888Ca3fe8e31cB2E34872FE0CE5309f","Deft2 Token Presale","https://defifactory.finance","https://t.me/DefiFactory",3153600000,0,60,30,120,"100000000000000000",1000000000000000,"1000000000000000000","1000000000000000000"]
Ropsten: ["0xe9961895C8820A05964b8Edf21E57c671D7f3fE9","Lambo Token Presale","https://lambo.defifactory.finance","https://t.me/LamboTokenOwners",3153600000,0,60,30,120,"1000000000000000000000",1000000000000000,"1000000000000000000","1000000000000000000"]
    */
    
    /* TODO: 
        - add custom presales 
        - max/min per wallet is zero
        - tokenomics missing uniswap and ref
        - 
    */
    
    function createPresale(
            Tokenomics[] memory _tokenomics,
            Settings memory _settings)
        external
        returns (address)
    {
        presaleContracts.push(
            new PresaleContract(
                msg.sender,
                _tokenomics,
                _settings
            )
        );
        
        return (address(presaleContracts[presaleContracts.length - 1]));
    }
    
    function listPresales(address walletAddress, uint page, uint limit)
        external
        view
        returns (OutputItem[] memory output)
    {
        uint start = (page-1) * limit;
        uint end = page * limit;
        end = (end > presaleContracts.length)? presaleContracts.length: end;
        uint numItems = (end > start)? end - start: 0;
        
        output = new OutputItem[](numItems);
        for(uint i = start; i < end; i++)
        {
            output[i - start] = presaleContracts[i].getInformation(walletAddress);
        }
        
        return output;
    }
}