// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.10;

struct TransactionInfo {
    bool isBuy;
    bool isSell;
}

interface ICerbyBotDetection {
    
    function getReceiveTimestamp(address tokenAddr, address addr)
        external
        view
        returns (uint);
    
    function updateTransaction(address tokenAddr, address sender, address recipient)
        external;
        
    function checkTransactionInfo(address tokenAddr, address sender, address recipient)
        external
        returns (TransactionInfo memory output);
    
    function isBotAddress(address addr)
        external
        view
        returns (bool);
}