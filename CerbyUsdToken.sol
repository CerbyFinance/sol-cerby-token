// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.12;

import "./CerbyBasedToken.sol";

contract CerbyUsdToken is CerbyBasedToken {

    // deploy 22 Feb 2022
    constructor() 
        CerbyBasedToken("Cerby USD Token", "cerUSD") 
    {
    }
}
