// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface IDeftStorageContract {
        
    function isHumanTransaction(address sender, address recipient)
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