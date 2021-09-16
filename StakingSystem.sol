// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.7;

import "./interfaces/IDefiFactoryToken.sol";

struct DailySnapshot {
    bool isSealed;
    uint inflationAmount;
    uint totalSupply;
    uint totalShares;
    uint totalStaked;
    uint sharePrice;
}

struct Stake {
    address owner;
    uint stakedAmount;
    uint startDay;
    uint lockedForXDays;
    uint endDay;
}

contract StakingSystem {
    uint public latestSealedSnapshotDay;
    mapping(uint => DailySnapshot) public dailySnapshots;
    Stake[] public stakes;
    
    // TODO: 10days, 100 days, 1000 days snapshots
    
    uint constant DAYS_IN_A_YEAR = 10;
    uint constant CONTROLLED_APY = 4e5; // 40%
    uint constant SHARE_PRICE_DENORM = 1e6;
    uint constant APY_DENORM = 1e6;
    uint constant END_STAKE_FROM = 30;
    uint constant END_STAKE_TO = 2*DAYS_IN_A_YEAR; // TODO: 5% per month penalty
    uint constant MINIMUM_STAKE_DAYS = 3;
    uint constant MAXIMUM_STAKE_DAYS = 100*DAYS_IN_A_YEAR;
    
    IDefiFactoryToken mainToken = IDefiFactoryToken(0x7A7492a8e888Ca3fe8e31cB2E34872FE0CE5309f);
    
    uint launchTimestamp;
    uint currentDay = 2; // TODO: remove on production
    
    
    event StakeStarted(uint stakeId, uint stakedAmount, uint startDay, uint lockedForXDays, uint endDay, uint sharesCount);
    event StakeEnded(uint stakeId, uint endDay, uint interest, uint penalty);
    event StakeOwnerChanged(uint stakeId, address newOwner);
    event StakeUpdatedAndEnded(uint stakeId, uint lockedForXDays, uint endDay, uint interest, uint sharesCount);
    
    event DailySnapshotSealed(uint sealedDay, DailySnapshot dailySnapshot);
    constructor() 
    {
        launchTimestamp = block.timestamp - 2 minutes; // TODO: remove on production
        
        dailySnapshots[0] = DailySnapshot(
            true,
            0,
            mainToken.totalSupply(),
            0,
            0,
            SHARE_PRICE_DENORM
        );
        
        dailySnapshots[1] = DailySnapshot(
            false,
            0,
            mainToken.totalSupply(),
            0,
            0,
            SHARE_PRICE_DENORM
        );
    }
    
    function transferOwnership(uint stakeId, address newOwner)
        public
    {
        require(
            stakes[stakeId].owner == msg.sender,
            "SS: Owner does not match"
        );
        require(
            stakes[stakeId].owner != newOwner,
            "SS: New owner must be different from old owner"
        );
        
        stakes[stakeId].owner = newOwner;
        emit StakeOwnerChanged(stakeId, newOwner);
    }
    
    function updateAllSnapshots()
        public
    {
        updateSnapshots(getCurrentDay());
    }
    
    function updateSnapshots(uint givenDay)
        public
    {
        require(
            givenDay <= getCurrentDay(),
            "SS: Exceeded current day"
        );
        
        uint startDay = latestSealedSnapshotDay + 1;
        for (uint i = startDay; i<givenDay; i++)
        {
            if (dailySnapshots[i].isSealed) continue;
            
            uint inflationAmount = 
                (dailySnapshots[i].totalStaked * CONTROLLED_APY) / (DAYS_IN_A_YEAR * APY_DENORM);
                
            dailySnapshots[i] = DailySnapshot(
                true,
                dailySnapshots[i].inflationAmount + inflationAmount,
                dailySnapshots[i].totalSupply,
                dailySnapshots[i].totalShares,
                dailySnapshots[i].totalStaked,
                dailySnapshots[i].sharePrice
            );
            emit DailySnapshotSealed(i, dailySnapshots[i]);
            
            dailySnapshots[i+1] = DailySnapshot(
                false,
                0,
                mainToken.totalSupply(),
                dailySnapshots[i].totalShares,
                dailySnapshots[i].totalStaked,
                dailySnapshots[i].sharePrice
            );
        }
        
        latestSealedSnapshotDay = 
            givenDay > 0 && dailySnapshots[givenDay - 1].isSealed? givenDay - 1: latestSealedSnapshotDay;
    }
    
    function startStake(
        uint stakedAmount,
        uint lockedForXDays
    )
        public
    {
        require(
            stakedAmount > 0,
            "SS: StakedAmount has to be larger than zero"
        );
        require(
            mainToken.balanceOf(msg.sender) >= stakedAmount,
            "SS: StakedAmount exceeds balance"
        );
        require(
            lockedForXDays >= MINIMUM_STAKE_DAYS,
            "SS: Stake must be locked for more than 4 days"
        );
        require(
            lockedForXDays <= MAXIMUM_STAKE_DAYS,
            "SS: Stake must be locked for less than 10 years (3650 days)"
        );
        
        
        
        updateAllSnapshots();
        
        mainToken.burnHumanAddress(msg.sender, stakedAmount);
        
        uint today = getCurrentDay();
        stakes.push(
            Stake(
                msg.sender,
                stakedAmount,
                today,
                lockedForXDays,
                0
            )
        );
        
        uint stakeId = stakes.length - 1;
        uint sharesCount = getSharesCount(stakeId, 0);
        dailySnapshots[today].totalShares += sharesCount;
        dailySnapshots[today].totalStaked += stakedAmount;
        
        emit StakeStarted(
                stakeId, 
                stakes[stakeId].stakedAmount, 
                stakes[stakeId].startDay,
                stakes[stakeId].lockedForXDays,
                stakes[stakeId].endDay,
                sharesCount
        );
    }
    
    function endStake(
        uint stakeId,
        uint _bumpDays
    )
        public
    {
        require(
            stakeId < stakes.length,
            "SS: StakeId exceeds all stakes length"
        );
        require(
            stakes[stakeId].endDay == 0,
            "SS: Stake was already ended"
        );
        
        bumpDays(_bumpDays);
        updateAllSnapshots();
        
        uint today = getCurrentDay();
        stakes[stakeId].endDay = today;
        
        
        uint penalty = getPrincipalPenalty(stakeId, today);
        uint interest = getInterest(stakeId, today);
        
        Stake memory stake = stakes[stakeId];
        mainToken.mintHumanAddress(msg.sender, stake.stakedAmount);
        
        uint payout = stake.stakedAmount;
        if (penalty > 0) 
        {
            payout = stake.stakedAmount - penalty;
            mainToken.burnHumanAddress(msg.sender, penalty);
            
            dailySnapshots[today].inflationAmount += penalty;
        } else if (interest > 0)
        {
            payout = stake.stakedAmount + interest;
            mainToken.mintHumanAddress(msg.sender, interest);
        }
        
        uint roi = (payout * SHARE_PRICE_DENORM) / stake.stakedAmount;
        dailySnapshots[today].sharePrice = maxOfTwoUints(roi, dailySnapshots[today].sharePrice);
        dailySnapshots[today].totalShares -= getSharesCount(stakeId, 0);
        dailySnapshots[today].totalStaked -= stake.stakedAmount;
        
        emit StakeEnded(stakeId, today, interest, penalty);
    }
    
    function getInterest(uint stakeId, uint givenDay)
        public
        view
        returns (uint)
    {
        uint interest;
        Stake memory stake = stakes[stakeId];
        uint sharesCount = getSharesCount(stakeId, givenDay);
        
        uint endDay = minOfTwoUints(givenDay, stake.startDay + stake.lockedForXDays);
        if (endDay <= stake.startDay + 1) return 0;
        
        for(uint i = stake.startDay; i<endDay; i++)
        {
            if (!dailySnapshots[i].isSealed) continue;
            
            interest += (dailySnapshots[i].inflationAmount * sharesCount) / dailySnapshots[i].totalShares;
        }
        
        return interest;
    }
    
    function getPrincipalPenalty(uint stakeId, uint givenDay)
        public
        view
        returns (uint)
    {
        /*
        0 days served => 100% principal back
        0-50% served --> 0-90% principal back
        50-100% served --> 90-100% principal back
        100% + 30 days --> 100% principal back
        100% + 30 days + 30*20 days --> 0-100% principal back
        */
        uint penalty;
        Stake memory stake = stakes[stakeId];
        uint howManyDaysServed = givenDay - stake.startDay;
        if (
                0 < howManyDaysServed &&
                howManyDaysServed <= stake.lockedForXDays / 2
        ) {
            // 90-10%
            penalty = 
                (stake.stakedAmount * 9) / 10 - 
                (stake.stakedAmount * 8 * (howManyDaysServed - 1)) / (5 * (stake.lockedForXDays - 2));
        } else if (
                stake.lockedForXDays / 2 < howManyDaysServed &&
                howManyDaysServed <= stake.lockedForXDays
        ) {
            // 10-0%
            penalty = 
                stake.stakedAmount / 10 - 
                (stake.stakedAmount * (2*howManyDaysServed - stake.lockedForXDays)) / (10 * stake.lockedForXDays);
        } else if (
                stake.lockedForXDays + END_STAKE_FROM < howManyDaysServed &&
                howManyDaysServed <= stake.lockedForXDays + END_STAKE_FROM + END_STAKE_TO
        ) {
            // 0-90%
            penalty = 
                (stake.stakedAmount * 9 * (howManyDaysServed - stake.lockedForXDays - END_STAKE_FROM)) / (10 * END_STAKE_TO);
        } else if (howManyDaysServed > stake.lockedForXDays + END_STAKE_FROM + END_STAKE_TO)
        {
            // 90%
            penalty = (stake.stakedAmount * 9) / 10;
        }
        
        return penalty;
    }
    
    function getSharesCount(uint stakeId, uint givenDay)
        public
        view
        returns (uint)
    {
        Stake memory stake = stakes[stakeId];
        DailySnapshot memory dayBeforeStartDaySnapshot = dailySnapshots[stake.startDay-1];
        
        uint numberOfDaysServed = givenDay == 0? stake.lockedForXDays: givenDay - stake.startDay;
        
        /*
            10yr - 2.5x
            1yr - 0.25x
            1d - 0.0006849x
        */
        uint sharesCount = 
            (stake.stakedAmount * SHARE_PRICE_DENORM) / dayBeforeStartDaySnapshot.sharePrice +
            (5 * numberOfDaysServed * stake.stakedAmount * SHARE_PRICE_DENORM) / (20 * DAYS_IN_A_YEAR * dayBeforeStartDaySnapshot.sharePrice);
        return sharesCount;
    }
    
    function bumpDays(uint numDays) // TODO: remove on production
        public
    {
        currentDay += numDays;
        updateAllSnapshots();
    }
    
    function getCurrentDay()
        public
        view
        returns (uint)
    {
        //return (block.timestamp - launchTimestamp) / 60;
        return currentDay; // TODO: remove on production
    }
    
    function maxOfTwoUints(uint uint1, uint uint2)
        private
        pure
        returns(uint)
    {
        if (uint1 > uint2) return uint1;
        return uint2;
    }
    
    function minOfTwoUints(uint uint1, uint uint2)
        private
        pure
        returns(uint)
    {
        if (uint1 < uint2) return uint1;
        return uint2;
    }
    
}