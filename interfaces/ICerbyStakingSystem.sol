// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.10;

struct DailySnapshot {
    uint256 inflationAmount;
    uint256 totalShares;
    uint256 sharePrice;
}
struct Stake {
    address owner;
    uint256 stakedAmount;
    uint256 startDay;
    uint256 lockedForXDays;
    uint256 endDay;
    uint256 maxSharesCountOnStartStake;
}

interface ICerbyStakingSystem {
    function getDailySnapshotsLength() external view returns (uint256);

    function getStakesLength() external view returns (uint256);

    function getCachedInterestPerShareLength() external view returns (uint256);

    function dailySnapshots(uint256 pos)
        external
        returns (DailySnapshot memory);

    function stakes(uint256 pos) external returns (Stake memory);

    function cachedInterestPerShare(uint256 pos) external returns (uint256);
}
