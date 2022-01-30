// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

struct AccessSettings {
    bool isMinter;
    bool isBurner;
    bool isTransferer;
    bool isModerator;
    bool isTaxer;
    address addr;
}

interface IDefiFactoryToken {
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address _spender, uint256 _value)
        external
        returns (bool success);

    function balanceOf(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function chargeCustomTax(address from, uint256 amount) external;

    function mintHumanAddress(address to, uint256 desiredAmountToMint) external;

    function burnHumanAddress(address from, uint256 desiredAmountToBurn)
        external;

    function mintByBridge(address to, uint256 realAmountToMint) external;

    function burnByBridge(address from, uint256 realAmountBurn) external;

    function getUtilsContractAtPos(uint256 pos) external view returns (address);

    function transferFromTeamVestingContract(address recipient, uint256 amount)
        external;

    function correctTransferEvents(address[] calldata addrs) external;

    function publicForcedUpdateCacheMultiplier() external;

    function updateUtilsContracts(AccessSettings[] calldata accessSettings)
        external;

    function transferCustom(
        address sender,
        address recipient,
        uint256 amount
    ) external;
}
