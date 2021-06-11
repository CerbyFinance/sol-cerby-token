// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.4;

struct IsHumanInfo {
    bool isHumanTransaction;
    bool isBuy;
    bool isSell;
    bool isBuyOtherTokenThroughDeft;
    bool isSellOtherTokenThroughDeft;
}

interface IDeftStorageContract {
    
    function getBuyTimestamp(address tokenAddr, address addr)
        external
        view
        returns (uint);
    
    function updateBuyTimestamp(address tokenAddr, address addr, uint newBuyTimestamp)
        external;
        
    function isHumanTransaction(address tokenAddr, address sender, address recipient)
        external
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
        
        
    function markPairAsDeftEthPair(address addr, bool value)
        external;
    
    function markPairAsDeftOtherPair(address addr, bool value)
        external;
}