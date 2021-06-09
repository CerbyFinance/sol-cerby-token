// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

struct IsHumanInfo {
    bool isHumanTransaction;
    bool isBuy;
    bool isSell;
    bool isBuyOtherTokenThroughDeft;
    bool isSellOtherTokenThroughDeft;
}

interface IDeftStorageContract {
        
    function isHumanTransaction(address tokenAddr, address sender, address recipient)
        external
        view
        returns (IsHumanInfo memory);
    
    function isBotAddress(address addr)
        external
        view
        returns (bool);
        
    function updateTransaction(address sender, address recipient)
        external;
    
    function bulkMarkAddressAsBot(address[] calldata addrs)
        external;
    
    function markAddressAsBot(address addr)
        external;
    
    function markAddressAsNotBot(address addr)
        external;
}