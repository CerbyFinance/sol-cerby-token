// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface IBotsStorage {
    function isBotStorage(address addr)
        external
        view
        returns(bool isBot);
    
    function bulkMarkAddressAsBot(address[] calldata addrs)
        external;
    
    function markAddressAsBot(address addr)
        external;
    
    function markAddressAsNotBot(address addr)
        external;
}