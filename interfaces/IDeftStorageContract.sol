// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.4;

struct TransactionInfo {
    bool isBuy;
    bool isSell;
    bool isHumanTransaction;
}

interface IDeftStorageContract {
    function getBuyTimestamp(address tokenAddr, address addr)
        external
        view
        returns (uint256);

    function updateBuyTimestamp(
        address tokenAddr,
        address addr,
        uint256 newBuyTimestamp
    ) external;

    function checkTransactionInfo(
        address tokenAddr,
        address sender,
        address recipient
    ) external returns (TransactionInfo memory);

    function isBotAddress(address addr) external view returns (bool);

    function isExcludedFromBalance(address addr) external view returns (bool);

    function bulkMarkAddressAsBot(address[] calldata addrs) external;

    function markAddressAsBot(address addr) external;

    function markAddressAsNotBot(address addr) external;

    function markPairAsDeftEthPair(address addr, bool value) external;

    function markPairAsDeftOtherPair(address addr, bool value) external;
}
