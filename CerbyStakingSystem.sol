// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.10;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/ICerbyStakingSystem.sol";
import "./CerbyCronJobsExecution.sol";

// Staking 0x8888888AC6aa2482265e5346832CDd963c70A0D1
// Bridge 0xEf038429e3BAaF784e1DE93075070df2A43D4278
// BotDetection 0x3C758A487A9c536882aEeAc341c62cb0F665ecf5
// Token 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840
// OldStaking 0xDef1Fafc79CD01Cf6797B9d7F51411beF486262a

struct StartStake {
    uint256 stakedAmount;
    uint256 lockedForXDays;
}

struct Settings {
    uint256 MINIMUM_DAYS_FOR_HIGH_PENALTY;
    uint256 CONTROLLED_APY;
    uint256 SMALLER_PAYS_BETTER_BONUS;
    uint256 LONGER_PAYS_BETTER_BONUS;
    uint256 END_STAKE_FROM;
    uint256 END_STAKE_TO;
    uint256 MINIMUM_STAKE_DAYS;
    uint256 MAXIMUM_STAKE_DAYS;
}

contract CerbyStakingSystem is AccessControlEnumerable, CerbyCronJobsExecution {
    DailySnapshot[] public dailySnapshots;
    uint256[] public cachedInterestPerShare;

    Stake[] public stakes;
    Settings public settings;

    uint256 constant MINIMUM_SMALLER_PAYS_BETTER = 1000 * 1e18; // 1k CERBY
    uint256 constant MAXIMUM_SMALLER_PAYS_BETTER = 1000000 * 1e18; // 1M CERBY
    uint256 constant CACHED_DAYS_INTEREST = 100;
    uint256 constant DAYS_IN_ONE_YEAR = 365;
    uint256 constant SHARE_PRICE_DENORM = 1e18;
    uint256 constant INTEREST_PER_SHARE_DENORM = 1e18;
    uint256 constant APY_DENORM = 1e6;
    uint256 constant SECONDS_IN_ONE_DAY = 86400;

    address constant BURN_WALLET = address(0x0);

    uint256 public launchTimestamp;

    event StakeStarted(
        uint256 stakeId,
        address owner,
        uint256 stakedAmount,
        uint256 startDay,
        uint256 lockedForXDays,
        uint256 sharesCount
    );
    event StakeEnded(
        uint256 stakeId,
        uint256 endDay,
        uint256 interest,
        uint256 penalty
    );
    event StakeOwnerChanged(uint256 stakeId, address newOwner);
    event StakeUpdated(
        uint256 stakeId,
        uint256 lockedForXDays,
        uint256 sharesCount
    );

    event DailySnapshotSealed(
        uint256 sealedDay,
        uint256 inflationAmount,
        uint256 totalShares,
        uint256 sharePrice,
        uint256 totalStaked,
        uint256 totalSupply
    );
    event CachedInterestPerShareSealed(
        uint256 sealedDay,
        uint256 sealedCachedDay,
        uint256 cachedInterestPerShare
    );

    event SettingsUpdated(Settings Settings);

    event NewMaxSharePriceReached(uint256 newSharePrice);

    event BurnedAndAddedToStakersInflation(
        address fromAddr,
        uint256 amountToBurn,
        uint256 currentDay
    );

    error CerbyStakingSystem_StakingIsAvailableOnlyWhileStakeIsInProgressStatus();
    error CerbyStakingSystem_ScrapingIsAvailableOnceInADay();
    error CerbyStakingSystem_StakeMustBeLockedForLessThanMaximumDays();
    error CerbyStakingSystem_StakeMustBeLockedForMoreThanMinimumDays();
    error CerbyStakingSystem_StakedAmountExceedsBalance();
    error CerbyStakingSystem_StakedAmountMustBeLargerThanZero();
    error CerbyStakingSystem_ExceededCurrentDay();
    error CerbyStakingSystem_NewOwnerMustBeDifferentFromTheOldOwner();
    error CerbyStakingSystem_StakeOwnerDoesNotMatch();
    error CerbyStakingSystem_StakeHaveBeenAlreadyEnded();
    error CerbyStakingSystem_StakeDoesNotExist();

    constructor() {
        settings.MINIMUM_DAYS_FOR_HIGH_PENALTY = 0;
        settings.CONTROLLED_APY = 4e5; // 40%
        settings.END_STAKE_FROM = 30;
        settings.END_STAKE_TO = 2 * DAYS_IN_ONE_YEAR; // 5% per month penalty
        settings.MINIMUM_STAKE_DAYS = 1;
        settings.MAXIMUM_STAKE_DAYS = 100 * DAYS_IN_ONE_YEAR;
        settings.LONGER_PAYS_BETTER_BONUS = 3e6; // 3e6/1e6 = 300% shares bonus max
        settings.SMALLER_PAYS_BETTER_BONUS = 25e4; // 25e4/1e6 = 25% shares bonus max

        launchTimestamp = 1635604537; // 30 October 2021

        dailySnapshots.push(DailySnapshot(0, 0, SHARE_PRICE_DENORM));
        emit DailySnapshotSealed(0, 0, 0, SHARE_PRICE_DENORM, 0, 0);
        dailySnapshots.push(DailySnapshot(0, 0, SHARE_PRICE_DENORM));
        cachedInterestPerShare.push(0);
        emit NewMaxSharePriceReached(SHARE_PRICE_DENORM);

        _setupRole(ROLE_ADMIN, msg.sender);
    }

    modifier onlyStakeOwners(uint256 stakeId) {
        if (msg.sender != stakes[stakeId].owner) {
            revert CerbyStakingSystem_StakeOwnerDoesNotMatch();
        }
        _;
    }

    modifier onlyExistingStake(uint256 stakeId) {
        if (stakeId >= stakes.length) {
            revert CerbyStakingSystem_StakeDoesNotExist();
        }
        _;
    }

    modifier onlyActiveStake(uint256 stakeId) {
        if (stakes[stakeId].endDay > 0) {
            revert CerbyStakingSystem_StakeHaveBeenAlreadyEnded();
        }
        _;
    }

    function adminUpdateSettings(Settings calldata _settings)
        public
        onlyRole(ROLE_ADMIN)
    {
        settings = _settings;

        emit SettingsUpdated(_settings);
    }

    function adminBulkTransferOwnership(
        uint256[] calldata stakeIds,
        address oldOwner,
        address newOwner
    ) public checkForBotsAndExecuteCronJobs(msg.sender) onlyRole(ROLE_ADMIN) {
        for (uint256 i = 0; i < stakeIds.length; i++) {
            if (stakes[stakeIds[i]].owner == newOwner) {
                revert CerbyStakingSystem_NewOwnerMustBeDifferentFromTheOldOwner();
            }
            if (stakes[stakeIds[i]].owner != oldOwner) {
                revert CerbyStakingSystem_StakeOwnerDoesNotMatch();
            }

            _transferOwnership(stakeIds[i], newOwner);
        }
    }

    function adminBulkDestroyStakes(
        uint256[] calldata stakeIds,
        address stakeOwner
    ) public checkForBotsAndExecuteCronJobs(msg.sender) onlyRole(ROLE_ADMIN) {
        uint256 today = getCurrentDaySinceLaunch();
        for (uint256 i = 0; i < stakeIds.length; i++) {
            if (stakes[stakeIds[i]].owner != stakeOwner) {
                revert CerbyStakingSystem_StakeOwnerDoesNotMatch();
            }

            dailySnapshots[today].totalShares -= stakes[stakeIds[i]]
                .maxSharesCountOnStartStake;
            stakes[stakeIds[i]].endDay = today;
            stakes[stakeIds[i]].owner = BURN_WALLET;

            ICerbyToken(CERBY_TOKEN_CONTRACT_ADDRESS).burnHumanAddress(
                address(this),
                stakes[stakeIds[i]].stakedAmount
            );

            emit StakeOwnerChanged(stakeIds[i], BURN_WALLET);
            emit StakeEnded(stakeIds[i], today, 0, 0);
        }
    }

    function adminMigrateInitialSnapshots(
        address fromStakingContract,
        uint256 fromIndex,
        uint256 toIndex
    ) public onlyRole(ROLE_ADMIN) {
        uint256 totalStaked = getTotalTokensStaked();
        uint256 totalSupply = ICerbyToken(CERBY_TOKEN_CONTRACT_ADDRESS)
            .totalSupply();
        ICerbyStakingSystem iStaking = ICerbyStakingSystem(fromStakingContract);
        toIndex = minOfTwoUints(toIndex, iStaking.getDailySnapshotsLength());
        for (uint256 i = fromIndex; i < toIndex; i++) {
            DailySnapshot memory snapshot = iStaking.dailySnapshots(i);
            if (dailySnapshots.length == i) {
                dailySnapshots.push(snapshot);
            } else if (dailySnapshots.length > i) {
                dailySnapshots[i] = snapshot;
            }
            emit DailySnapshotSealed(
                i,
                snapshot.inflationAmount,
                snapshot.totalShares,
                snapshot.sharePrice,
                totalStaked,
                totalSupply
            );
            emit NewMaxSharePriceReached(snapshot.sharePrice);
        }
    }

    function adminMigrateInitialStakes(
        address fromStakingContract,
        uint256 fromIndex,
        uint256 toIndex
    ) public onlyRole(ROLE_ADMIN) {
        ICerbyStakingSystem iStaking = ICerbyStakingSystem(fromStakingContract);
        toIndex = minOfTwoUints(toIndex, iStaking.getStakesLength());
        for (uint256 i = fromIndex; i < toIndex; i++) {
            Stake memory stake = iStaking.stakes(i);
            if (stakes.length == i) {
                stakes.push(stake);
            } else if (stakes.length > i) {
                stakes[i] = stake;
            }

            emit StakeStarted(
                i,
                stake.owner,
                stake.stakedAmount,
                stake.startDay,
                stake.lockedForXDays,
                stake.maxSharesCountOnStartStake
            );

            if (stake.endDay > 0) {
                uint256 endDay = stake.endDay;
                uint256 interest = getInterestByStake(stake, endDay);
                uint256 penalty = getPenaltyByStake(stake, endDay, interest);

                emit StakeEnded(i, endDay, interest, penalty);
            }
        }
    }

    function adminMigrateInitialInterestPerShare(
        address fromStakingContract,
        uint256 fromIndex,
        uint256 toIndex
    ) public onlyRole(ROLE_ADMIN) {
        ICerbyStakingSystem iStaking = ICerbyStakingSystem(fromStakingContract);
        toIndex = minOfTwoUints(
            toIndex,
            iStaking.getCachedInterestPerShareLength()
        );
        for (uint256 i = fromIndex; i < toIndex; i++) {
            uint256 cachedInterestPerShareValue = iStaking
                .cachedInterestPerShare(i);
            if (cachedInterestPerShare.length == i) {
                cachedInterestPerShare.push(cachedInterestPerShareValue);
            } else if (stakes.length > i) {
                cachedInterestPerShare[i] = cachedInterestPerShareValue;
            }

            uint256 sealedDay = i * CACHED_DAYS_INTEREST;
            emit CachedInterestPerShareSealed(
                sealedDay,
                i,
                cachedInterestPerShareValue
            );
        }
    }

    function adminBurnAndAddToStakersInflation(
        address fromAddr,
        uint256 amountToBurn
    ) public checkForBotsAndExecuteCronJobs(msg.sender) onlyRole(ROLE_ADMIN) {
        ICerbyToken(CERBY_TOKEN_CONTRACT_ADDRESS).burnHumanAddress(
            fromAddr,
            amountToBurn
        );

        uint256 today = getCurrentDaySinceLaunch();
        dailySnapshots[today].inflationAmount += amountToBurn;

        emit BurnedAndAddedToStakersInflation(fromAddr, amountToBurn, today);
    }

    function bulkTransferOwnership(
        uint256[] calldata stakeIds,
        address newOwner
    ) public checkForBotsAndExecuteCronJobs(msg.sender) {
        for (uint256 i = 0; i < stakeIds.length; i++) {
            transferOwnership(stakeIds[i], newOwner);
        }
    }

    function transferOwnership(uint256 stakeId, address newOwner)
        private
        onlyStakeOwners(stakeId)
        onlyExistingStake(stakeId)
        onlyActiveStake(stakeId)
    {
        if (stakes[stakeId].owner == newOwner) {
            revert CerbyStakingSystem_NewOwnerMustBeDifferentFromTheOldOwner();
        }

        _transferOwnership(stakeId, newOwner);
    }

    function _transferOwnership(uint256 stakeId, address newOwner) private {
        stakes[stakeId].owner = newOwner;
        emit StakeOwnerChanged(stakeId, newOwner);
    }

    function updateAllSnapshots() public {
        updateSnapshots(getCurrentDaySinceLaunch());
    }

    function updateSnapshots(uint256 givenDay) public {
        if (givenDay > getCurrentDaySinceLaunch()) {
            revert CerbyStakingSystem_ExceededCurrentDay();
        }

        uint256 startDay = dailySnapshots.length - 1; // last sealed day
        if (startDay == givenDay) return;

        for (uint256 i = startDay; i < givenDay; i++) {
            uint256 currentSnapshotIndex = dailySnapshots.length > i
                ? i
                : dailySnapshots.length - 1;
            uint256 sharesCount = ((settings.LONGER_PAYS_BETTER_BONUS +
                APY_DENORM) * SHARE_PRICE_DENORM) /
                (APY_DENORM * dailySnapshots[currentSnapshotIndex].sharePrice);
            uint256 inflationAmount = (settings.CONTROLLED_APY *
                (dailySnapshots[currentSnapshotIndex].totalShares +
                    sharesCount)) /
                (sharesCount * DAYS_IN_ONE_YEAR * APY_DENORM);

            if (dailySnapshots.length > i) {
                dailySnapshots[currentSnapshotIndex]
                    .inflationAmount += inflationAmount;
            } else {
                dailySnapshots.push(
                    DailySnapshot(
                        inflationAmount,
                        dailySnapshots[currentSnapshotIndex].totalShares,
                        dailySnapshots[currentSnapshotIndex].sharePrice
                    )
                );
            }
            emit DailySnapshotSealed(
                i,
                dailySnapshots[currentSnapshotIndex].inflationAmount,
                dailySnapshots[currentSnapshotIndex].totalShares,
                dailySnapshots[currentSnapshotIndex].sharePrice,
                getTotalTokensStaked(),
                ICerbyToken(CERBY_TOKEN_CONTRACT_ADDRESS).totalSupply()
            );
        }

        if (dailySnapshots.length == givenDay) {
            dailySnapshots.push(
                DailySnapshot(
                    0,
                    dailySnapshots[givenDay - 1].totalShares,
                    dailySnapshots[givenDay - 1].sharePrice
                )
            );
        }

        uint256 startCachedDay = cachedInterestPerShare.length - 1;
        uint256 endCachedDay = givenDay / CACHED_DAYS_INTEREST;
        for (uint256 i = startCachedDay; i < endCachedDay; i++) {
            uint256 interestPerShare;
            for (
                uint256 j = i * CACHED_DAYS_INTEREST;
                j < (i + 1) * CACHED_DAYS_INTEREST;
                j++
            ) {
                if (dailySnapshots[j].totalShares == 0) continue;

                interestPerShare +=
                    (dailySnapshots[j].inflationAmount *
                        INTEREST_PER_SHARE_DENORM) /
                    dailySnapshots[j].totalShares;
            }

            if (cachedInterestPerShare.length > i) {
                cachedInterestPerShare[i] = interestPerShare;
            } else {
                cachedInterestPerShare.push(interestPerShare);
            }
            emit CachedInterestPerShareSealed(
                i, // sealedDay
                cachedInterestPerShare.length - 1, // sealedCachedDay
                interestPerShare
            );
        }
        if (cachedInterestPerShare.length == endCachedDay) {
            cachedInterestPerShare.push(0);
        }
    }

    function bulkStartStake(StartStake[] calldata startStakes)
        public
        checkForBotsAndExecuteCronJobs(msg.sender)
    {
        for (uint256 i; i < startStakes.length; i++) {
            startStake(startStakes[i]);
        }
    }

    function startStake(StartStake memory _startStake)
        private
        returns (uint256 stakeId)
    {
        if (_startStake.stakedAmount == 0) {
            revert CerbyStakingSystem_StakedAmountMustBeLargerThanZero();
        }
        if (
            _startStake.stakedAmount >
            ICerbyToken(CERBY_TOKEN_CONTRACT_ADDRESS).balanceOf(msg.sender)
        ) {
            revert CerbyStakingSystem_StakedAmountExceedsBalance();
        }
        if (_startStake.lockedForXDays < settings.MINIMUM_STAKE_DAYS) {
            revert CerbyStakingSystem_StakeMustBeLockedForMoreThanMinimumDays();
        }
        if (_startStake.lockedForXDays > settings.MAXIMUM_STAKE_DAYS) {
            revert CerbyStakingSystem_StakeMustBeLockedForLessThanMaximumDays();
        }

        ICerbyToken(CERBY_TOKEN_CONTRACT_ADDRESS).transferCustom(
            msg.sender,
            address(this),
            _startStake.stakedAmount
        );

        uint256 today = getCurrentDaySinceLaunch();
        Stake memory stake = Stake(
            msg.sender,
            _startStake.stakedAmount,
            today,
            _startStake.lockedForXDays,
            0,
            0
        );
        stake.maxSharesCountOnStartStake = getSharesCountByStake(stake, 0);

        stakes.push(stake);
        stakeId = stakes.length - 1;

        dailySnapshots[today].totalShares += stake.maxSharesCountOnStartStake;

        emit StakeStarted(
            stakeId,
            stake.owner,
            stake.stakedAmount,
            stake.startDay,
            stake.lockedForXDays,
            stake.maxSharesCountOnStartStake
        );

        return stakeId;
    }

    function bulkEndStake(uint256[] calldata stakeIds)
        public
        checkForBotsAndExecuteCronJobs(msg.sender)
    {
        for (uint256 i; i < stakeIds.length; i++) {
            endStake(stakeIds[i]);
        }
    }

    function endStake(uint256 stakeId)
        private
        onlyStakeOwners(stakeId)
        onlyExistingStake(stakeId)
        onlyActiveStake(stakeId)
    {
        uint256 today = getCurrentDaySinceLaunch();
        stakes[stakeId].endDay = today;

        ICerbyToken(CERBY_TOKEN_CONTRACT_ADDRESS).transferCustom(
            address(this),
            msg.sender,
            stakes[stakeId].stakedAmount
        );

        uint256 interest;
        if (today < stakes[stakeId].startDay + stakes[stakeId].lockedForXDays) {
            // Early end stake: Calculating interest similar to scrapeStake one
            Stake memory modifiedStakeToGetInterest = stakes[stakeId];
            modifiedStakeToGetInterest.lockedForXDays =
                today -
                stakes[stakeId].startDay;

            interest = getInterestByStake(modifiedStakeToGetInterest, today);
        } else {
            // Late or correct end stake
            interest = getInterestByStake(stakes[stakeId], today);
        }

        if (interest > 0) {
            ICerbyToken(CERBY_TOKEN_CONTRACT_ADDRESS).mintHumanAddress(
                msg.sender,
                interest
            );
        }

        uint256 penalty = getPenaltyByStake(stakes[stakeId], today, interest);
        if (penalty > 0) {
            ICerbyToken(CERBY_TOKEN_CONTRACT_ADDRESS).burnHumanAddress(
                msg.sender,
                penalty
            );
            dailySnapshots[today].inflationAmount += penalty;
        }

        uint256 payout = stakes[stakeId].stakedAmount + interest - penalty;
        uint256 ROI = (payout * SHARE_PRICE_DENORM) /
            stakes[stakeId].stakedAmount;
        if (ROI > dailySnapshots[today].sharePrice) {
            dailySnapshots[today].sharePrice = ROI;
            emit NewMaxSharePriceReached(ROI);
        }

        dailySnapshots[today].totalShares -= stakes[stakeId]
            .maxSharesCountOnStartStake;

        emit StakeEnded(stakeId, today, interest, penalty);
    }

    function bulkScrapeStake(uint256[] calldata stakeIds)
        public
        checkForBotsAndExecuteCronJobs(msg.sender)
    {
        for (uint256 i; i < stakeIds.length; i++) {
            scrapeStake(stakeIds[i]);
        }
    }

    function scrapeStake(uint256 stakeId)
        private
        onlyStakeOwners(stakeId)
        onlyExistingStake(stakeId)
        onlyActiveStake(stakeId)
    {
        uint256 today = getCurrentDaySinceLaunch();
        if (today <= stakes[stakeId].startDay) {
            revert CerbyStakingSystem_ScrapingIsAvailableOnceInADay();
        }
        if (today > stakes[stakeId].startDay + stakes[stakeId].lockedForXDays) {
            revert CerbyStakingSystem_StakingIsAvailableOnlyWhileStakeIsInProgressStatus();
        }

        uint256 oldLockedForXDays = stakes[stakeId].lockedForXDays;
        uint256 oldSharesCount = stakes[stakeId].maxSharesCountOnStartStake;

        stakes[stakeId].lockedForXDays = today - stakes[stakeId].startDay;
        uint256 newSharesCount = getSharesCountByStake(stakes[stakeId], 0);

        dailySnapshots[today].totalShares =
            dailySnapshots[today].totalShares -
            oldSharesCount +
            newSharesCount;
        stakes[stakeId].maxSharesCountOnStartStake = newSharesCount;

        emit StakeUpdated(
            stakeId,
            stakes[stakeId].lockedForXDays,
            newSharesCount
        );

        endStake(stakeId);

        uint256 newLockedForXDays = oldLockedForXDays -
            stakes[stakeId].lockedForXDays;
        startStake(StartStake(stakes[stakeId].stakedAmount, newLockedForXDays));
    }

    function getTotalTokensStaked() public view returns (uint256) {
        return
            ICerbyToken(CERBY_TOKEN_CONTRACT_ADDRESS).balanceOf(address(this));
    }

    function getDailySnapshotsLength() public view returns (uint256) {
        return dailySnapshots.length;
    }

    function getCachedInterestPerShareLength() public view returns (uint256) {
        return cachedInterestPerShare.length;
    }

    function getStakesLength() public view returns (uint256) {
        return stakes.length;
    }

    function getInterestById(uint256 stakeId, uint256 givenDay)
        public
        view
        returns (uint256)
    {
        return getInterestByStake(stakes[stakeId], givenDay);
    }

    function getInterestByStake(Stake memory stake, uint256 givenDay)
        public
        view
        returns (uint256)
    {
        if (givenDay <= stake.startDay) return 0;

        uint256 interest;

        uint256 endDay = minOfTwoUints(
            givenDay,
            stake.startDay + stake.lockedForXDays
        );
        endDay = minOfTwoUints(endDay, dailySnapshots.length);

        uint256 sharesCount = getSharesCountByStake(stake, givenDay);
        uint256 startCachedDay = stake.startDay / CACHED_DAYS_INTEREST + 1;
        uint256 endBeforeFirstCachedDay = minOfTwoUints(
            endDay,
            startCachedDay * CACHED_DAYS_INTEREST
        );
        for (uint256 i = stake.startDay; i < endBeforeFirstCachedDay; i++) {
            if (dailySnapshots[i].totalShares == 0) continue;

            interest +=
                (dailySnapshots[i].inflationAmount * sharesCount) /
                dailySnapshots[i].totalShares;
        }

        uint256 endCachedDay = endDay / CACHED_DAYS_INTEREST;
        for (uint256 i = startCachedDay; i < endCachedDay; i++) {
            interest +=
                (cachedInterestPerShare[i] * sharesCount) /
                INTEREST_PER_SHARE_DENORM;
        }

        uint256 startAfterLastCachedDay = endDay -
            (endDay % CACHED_DAYS_INTEREST);
        if (
            startAfterLastCachedDay > stake.startDay
        ) // do not double iterate if numberOfDaysServed < CACHED_DAYS_INTEREST
        {
            for (uint256 i = startAfterLastCachedDay; i < endDay; i++) {
                if (dailySnapshots[i].totalShares == 0) continue;

                interest +=
                    (dailySnapshots[i].inflationAmount * sharesCount) /
                    dailySnapshots[i].totalShares;
            }
        }

        return interest;
    }

    function getPenaltyById(
        uint256 stakeId,
        uint256 givenDay,
        uint256 interest
    ) public view returns (uint256) {
        return getPenaltyByStake(stakes[stakeId], givenDay, interest);
    }

    function getPenaltyByStake(
        Stake memory stake,
        uint256 givenDay,
        uint256 interest
    ) public view returns (uint256) {
        /*
        0 -- 0 days served => 0% principal back
        0 days -- 100% served --> 0-100% (principal+interest) back
        100% + 30 days --> 100% (principal+interest) back
        100% + 30 days -- 100% + 30 days + 2*365 days --> 100-10% (principal+interest) back
        > 100% + 30 days + 30*20 days --> 10% (principal+interest) back
        */
        uint256 penalty;
        uint256 howManyDaysServed = givenDay > stake.startDay
            ? givenDay - stake.startDay
            : 0;
        uint256 riskAmount = stake.stakedAmount + interest;

        if (
            howManyDaysServed <= settings.MINIMUM_DAYS_FOR_HIGH_PENALTY
        ) // Stake just started or less than 7 days passed)
        {
            penalty = riskAmount; // 100%
        } else if (howManyDaysServed <= stake.lockedForXDays) {
            // 100-0%
            penalty =
                (riskAmount * (stake.lockedForXDays - howManyDaysServed)) /
                (stake.lockedForXDays - settings.MINIMUM_DAYS_FOR_HIGH_PENALTY);
        } else if (
            howManyDaysServed <= stake.lockedForXDays + settings.END_STAKE_FROM
        ) {
            penalty = 0;
        } else if (
            howManyDaysServed <=
            stake.lockedForXDays +
                settings.END_STAKE_FROM +
                settings.END_STAKE_TO
        ) {
            // 0-90%
            penalty =
                (riskAmount *
                    9 *
                    (howManyDaysServed -
                        stake.lockedForXDays -
                        settings.END_STAKE_FROM)) /
                (10 * settings.END_STAKE_TO);
        }
        // if (howManyDaysServed > stake.lockedForXDays + settings.END_STAKE_FROM + settings.END_STAKE_TO)
        else {
            // 90%
            penalty = (riskAmount * 9) / 10;
        }

        return penalty;
    }

    function getSharesCountById(uint256 stakeId, uint256 givenDay)
        public
        view
        returns (uint256)
    {
        return getSharesCountByStake(stakes[stakeId], givenDay);
    }

    function getSharesCountByStake(Stake memory stake, uint256 givenDay)
        public
        view
        returns (uint256)
    {
        uint256 numberOfDaysServed;
        if (givenDay == 0) {
            numberOfDaysServed = stake.lockedForXDays;
        } else if (givenDay > stake.startDay) {
            numberOfDaysServed = givenDay - stake.startDay;
        }
        // givenDay > 0 && givenDay < stake.startDay
        else {
            return 0;
        }
        numberOfDaysServed = minOfTwoUints(
            numberOfDaysServed,
            10 * DAYS_IN_ONE_YEAR
        );

        uint256 initialSharesCount = (stake.stakedAmount * SHARE_PRICE_DENORM) /
            dailySnapshots[stake.startDay].sharePrice;
        uint256 longerPaysBetterSharesCount = (settings
            .LONGER_PAYS_BETTER_BONUS *
            numberOfDaysServed *
            stake.stakedAmount *
            SHARE_PRICE_DENORM) /
            (APY_DENORM *
                10 *
                DAYS_IN_ONE_YEAR *
                dailySnapshots[stake.startDay].sharePrice);
        uint256 smallerPaysBetterSharesCountMultiplier;
        if (stake.stakedAmount <= MINIMUM_SMALLER_PAYS_BETTER) {
            smallerPaysBetterSharesCountMultiplier =
                APY_DENORM +
                settings.SMALLER_PAYS_BETTER_BONUS;
        } else if (
            MINIMUM_SMALLER_PAYS_BETTER < stake.stakedAmount &&
            stake.stakedAmount < MAXIMUM_SMALLER_PAYS_BETTER
        ) {
            smallerPaysBetterSharesCountMultiplier =
                APY_DENORM +
                (settings.SMALLER_PAYS_BETTER_BONUS *
                    (MAXIMUM_SMALLER_PAYS_BETTER - stake.stakedAmount)) /
                (MAXIMUM_SMALLER_PAYS_BETTER - MINIMUM_SMALLER_PAYS_BETTER);
        }
        // MAXIMUM_SMALLER_PAYS_BETTER >= stake.stakedAmount
        else {
            smallerPaysBetterSharesCountMultiplier = APY_DENORM;
        }
        uint256 sharesCount = ((initialSharesCount +
            longerPaysBetterSharesCount) *
            smallerPaysBetterSharesCountMultiplier) / APY_DENORM;

        return sharesCount;
    }

    function getCurrentDaySinceLaunch() public view returns (uint256) {
        return
            1 +
            block.timestamp /
            SECONDS_IN_ONE_DAY -
            launchTimestamp /
            SECONDS_IN_ONE_DAY;
    }

    function getCurrentCachedPerShareDay() public view returns (uint256) {
        return getCurrentDaySinceLaunch() / CACHED_DAYS_INTEREST;
    }

    function minOfTwoUints(uint256 uint1, uint256 uint2)
        private
        pure
        returns (uint256)
    {
        if (uint1 < uint2) return uint1;
        return uint2;
    }
}
