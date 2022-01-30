// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

struct TaxAmountsInput {
    address sender;
    address recipient;
    uint256 transferAmount;
    uint256 senderRealBalance;
    uint256 recipientRealBalance;
}
struct TaxAmountsOutput {
    uint256 senderRealBalance;
    uint256 recipientRealBalance;
    uint256 burnAndRewardAmount;
    uint256 recipientGetsAmount;
}

interface INoBotsTech {
    function botTaxPercent() external returns (uint256);

    function prepareTaxAmounts(TaxAmountsInput calldata taxAmountsInput)
        external
        returns (TaxAmountsOutput memory taxAmountsOutput);

    function updateSupply(uint256 _realTotalSupply, uint256 _rewardsBalance)
        external;

    function prepareHumanAddressMintOrBurnRewardsAmounts(
        bool isMint,
        address account,
        uint256 desiredAmountToMintOrBurn
    ) external returns (uint256 realAmountToMintOrBurn);

    function getBalance(address account, uint256 accountBalance)
        external
        view
        returns (uint256);

    function getRealBalance(address account, uint256 accountBalance)
        external
        view
        returns (uint256);

    function getRealBalanceTeamVestingContract(uint256 accountBalance)
        external
        view
        returns (uint256);

    function getTotalSupply() external view returns (uint256);

    function grantRole(bytes32 role, address account) external;

    function chargeCustomTax(uint256 taxAmount, uint256 accountBalance)
        external
        returns (uint256);

    function chargeCustomTaxTeamVestingContract(
        uint256 taxAmount,
        uint256 accountBalance
    ) external returns (uint256);

    function publicForcedUpdateCacheMultiplier() external;
}
