// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./openzeppelin/access/AccessControlEnumerable.sol";

contract BotsStorage is AccessControlEnumerable {
    mapping(address => bool) public isBotStorage;
    
    event BulkMarkedAsBot(address[] addrs);
    event MarkedAsBot(address addr);
    event MarkedAsNotBot(address addr);
    
    constructor() {
        _setupRole(ROLE_ADMIN, _msgSender());
    }
    
    function bulkMarkAddressAsBot(address[] calldata addrs)
        external
        onlyRole(ROLE_ADMIN)
    {
        for(uint i = 0; i<addrs.length; i++)
        {
            isBotStorage[addrs[i]] = true;
        }
        emit BulkMarkedAsBot(addrs);
    }
    
    function markAddressAsBot(address addr)
        external
        onlyRole(ROLE_ADMIN)
    {
        isBotStorage[addr] = true;
        emit MarkedAsBot(addr);
    }
    
    function markAddressAsNotBot(address addr)
        external
        onlyRole(ROLE_ADMIN)
    {
        isBotStorage[addr] = false;
        emit MarkedAsNotBot(addr);
    }
}