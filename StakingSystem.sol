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
    uint stakedAmount;
    uint startDay;
    uint lockedForXDays;
    uint endDay;
}

contract StakingSystem {
    uint public latestSealedSnapshotDay;
    mapping(uint => DailySnapshot) public dailySnapshots;
    mapping(address => Stake[]) public stakers;
    
    // TODO: 10days, 100 days, 1000 days snapshots
    
    uint constant SHARE_PRICE_DENORM = 1e6;
    uint constant END_STAKE_FROM = 30;
    uint constant END_STAKE_TO = 365*2; // TODO: 5% per month penalty
    uint constant MINIMUM_STAKE_DAYS = 3;
    uint constant MAXIMUM_STAKE_DAYS = 3650;
    
    IDefiFactoryToken mainToken = IDefiFactoryToken(0x7A7492a8e888Ca3fe8e31cB2E34872FE0CE5309f);
    
    uint launchTimestamp;
    uint currentDay = 2; // TODO: remove on production
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
    
    function updateAllSnapshots()
        public
    {
        updateSnapshots(getCurrentDay());
    }
    
    function updateSnapshots(uint givenDay)
        public
    {
        // TODO: require givenDay <= today
        
        uint startDat = latestSealedSnapshotDay + 1;
        for (uint i = startDat; i<givenDay; i++)
        {
            if (dailySnapshots[i].isSealed) continue;
            
            // TODO: 40% APY control
            uint inflationAmount = 
                dailySnapshots[i].inflationAmount + 
                    ((dailySnapshots[i].totalSupply + dailySnapshots[i].totalStaked) * 10) / 100;
                
            dailySnapshots[i] = DailySnapshot(
                true,
                inflationAmount,
                dailySnapshots[i].totalSupply,
                dailySnapshots[i].totalShares,
                dailySnapshots[i].totalStaked,
                dailySnapshots[i].sharePrice
            );
            
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
        stakers[msg.sender].push(
            Stake(
                stakedAmount,
                today,
                lockedForXDays,
                0
            )
        );
        
        uint sharesCount = getSharesCount(msg.sender, stakers[msg.sender].length - 1, 0);
        dailySnapshots[today].totalShares += sharesCount;
        dailySnapshots[today].totalStaked += stakedAmount;
    }
    
    function endStake(
        uint stakePosition
    )
        public
    {
        require(
            stakePosition < stakers[msg.sender].length,
            "SS: StakePosition exceeds staker length"
        );
        require(
            stakers[msg.sender][stakePosition].endDay == 0,
            "SS: Stake was already ended"
        );
        
        uint today = getCurrentDay();
        stakers[msg.sender][stakePosition].endDay = today;
        
        updateAllSnapshots();
        
        uint penalty = getPrincipalPenalty(msg.sender, stakePosition, today);
        uint interest = getInterest(msg.sender, stakePosition, today);
        
        Stake memory stake = stakers[msg.sender][stakePosition];
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
        dailySnapshots[today].totalShares -= getSharesCount(msg.sender, stakePosition, 0);
        dailySnapshots[today].totalStaked -= stake.stakedAmount;
    }
    
    function getInterest(address stakerAddress, uint stakePosition, uint givenDay)
        public
        view
        returns (uint)
    {
        uint interest;
        Stake memory stake = stakers[stakerAddress][stakePosition];
        uint sharesCount = getSharesCount(stakerAddress, stakePosition, givenDay);
        
        uint endDay = minOfTwoUints(givenDay, stake.startDay + stake.lockedForXDays);
        if (endDay <= stake.startDay + 1) return 0;
        
        for(uint i = stake.startDay; i<endDay; i++)
        {
            if (!dailySnapshots[i].isSealed) continue;
            
            interest += (dailySnapshots[i].inflationAmount * sharesCount) / dailySnapshots[i].totalShares;
        }
        
        return interest;
    }
    
    function getPrincipalPenalty(address stakerAddress, uint stakePosition, uint givenDay)
        public
        view
        returns (uint)
    {
        /*
        0 days served => 100% principal back
        0-50% served --> 0-90% principal back
        50-100% served --> 90-100% principal back
        100% + 30 days --> 100% principal back
        100% + 2*30 days + 30*10 days --> 0-100% principal back
        */
        uint penalty;
        Stake memory stake = stakers[stakerAddress][stakePosition];
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
    
    function getSharesCount(address stakerAddress, uint stakePosition, uint givenDay)
        public
        view
        returns (uint)
    {
        Stake memory stake = stakers[stakerAddress][stakePosition];
        DailySnapshot memory dayBeforeStartDaySnapshot = dailySnapshots[stake.startDay-1];
        
        uint numberOfDaysServed = givenDay == 0? stake.lockedForXDays: givenDay - stake.startDay;
        
        /*
            10yr - 2.5x
            1yr - 0.25x
            1d - 0.0006849x
        */
        uint sharesCount = 
            (stake.stakedAmount * SHARE_PRICE_DENORM) / dayBeforeStartDaySnapshot.sharePrice +
            (5 * numberOfDaysServed * stake.stakedAmount * SHARE_PRICE_DENORM) / (20 * 365 * dayBeforeStartDaySnapshot.sharePrice);
        return sharesCount;
    }
    
    function bumpDays(uint numDays)
        public
    {
        currentDay += numDays;
    }
    
    function getCurrentDay()
        public
        view
        returns (uint)
    {
        //return (block.timestamp - launchTimestamp) / 60;
        return currentDay;
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