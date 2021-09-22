// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.7;

import "./PresaleContract.sol";

contract PresaleFactory {
    
    
    
    PresaleContract[] public presaleContracts;
    
    
    /*
0xDc15Ca882F975c33D8f20AB3669D27195B8D87a6
0xE019B37896f129354cf0b8f1Cf33936b86913A34
0xF47440956c27f0F1AE585CFDaa024bbD35C3e6c6
    
[
    ["0x1111BEe701Ef814A2B6A3EDD4B1652cB9cc5aA6f","Development",150000,60,600],
    ["0x2222bEE701Ef814a2B6a3edD4B1652cB9Cc5Aa6F","Marketing",100000,120,1200],
    ["0x3333BeE701EF814A2b6a3edD4B1652cb9Cc5AA6F","Advisors",50000,180,1800]
]

Kovan: ["0xe4F85af0DDC43DDd18f78F76ec64046E1940ECe8","Some3 Token Presale","https://defifactory.finance","https://t.me/DefiFactory","3153600000",0,60,30,120,"1000000000000000000","10000000000000000","1000000000000000000","1000000000000000000000"]
Ropsten: ["0xe9961895C8820A05964b8Edf21E57c671D7f3fE9","Lambo1 Token Presale","https://lambo.defifactory.finance","https://t.me/LamboTokenOwners",3153600000,0,60,30,120,"1000000000000000000000",1000000000000000,"1000000000000000000","1000000000000000000"]
BSC: ["0x923480ad9b9EcDd933212C6531B93a6129e24671","Tesla3 Token Presale","https://lambo.defifactory.finance","https://t.me/LamboTokenOwners",3153600000,0,60,30,120,"100000000000000000",1000000000000000,"1000000000000000000","1000000000000000000"]
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