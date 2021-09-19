// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.7;

import "./interfaces/IDefiFactoryToken.sol";

struct DailySnapshot {
    uint inflationAmount;
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
    DailySnapshot[] public dailySnapshots;
    uint[] public tenDaysInterestPerShare;
    Stake[] public stakes;
    
    // TODO: 10days, 100 days, 1000 days snapshots
    // 1000000000000000000000
    
    uint constant DAYS_IN_A_YEAR = 5;
    uint constant CONTROLLED_APY = 4e5; // 40%
    uint constant SHARE_PRICE_DENORM = 1e6;
    uint constant INTEREST_PER_SHARE_DENORM = 1e18;
    uint constant APY_DENORM = 1e6;
    uint constant END_STAKE_FROM = 7;
    uint constant END_STAKE_TO = 2*DAYS_IN_A_YEAR; // TODO: 5% per month penalty
    uint constant MINIMUM_STAKE_DAYS = 3;
    uint constant MAXIMUM_STAKE_DAYS = 100*DAYS_IN_A_YEAR;
    uint constant SHARE_MULTIPLIER_NUMERATOR = 5;
    uint constant SHARE_MULTIPLIER_DENOMINATOR = 2;
    
    IDefiFactoryToken mainToken = IDefiFactoryToken(0x7A7492a8e888Ca3fe8e31cB2E34872FE0CE5309f);
    
    uint launchTimestamp;
    uint currentDay = 2; // TODO: remove on production
    
    
    event StakeStarted(uint stakeId, address owner, uint stakedAmount, uint startDay, uint lockedForXDays, uint sharesCount);
    event StakeEnded(uint stakeId, uint endDay, uint interest, uint penalty);
    event StakeOwnerChanged(uint stakeId, address newOwner);
    event StakeUpdatedAndEnded(uint stakeId, uint lockedForXDays, uint endDay, uint interest, uint sharesCount);
    
    event DailySnapshotSealed(uint sealedDay, DailySnapshot dailySnapshot, uint totalSupply);
    event TenDaysInterestPerShareSealed(uint sealedDay, uint _tenDaysInterestPerShare);
    constructor() 
    {
        launchTimestamp = block.timestamp - 2 minutes; // TODO: remove on production
        
        uint totalSupply = mainToken.totalSupply();
        dailySnapshots.push(DailySnapshot(
            0,
            0,
            0,
            SHARE_PRICE_DENORM
        ));
        dailySnapshots.push(DailySnapshot(
            0,
            0,
            0,
            SHARE_PRICE_DENORM
        ));
        
        tenDaysInterestPerShare.push(0);
    }
    
    // 0xDc15Ca882F975c33D8f20AB3669D27195B8D87a6
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
        updateSnapshots(getCurrentOneDay());
    }
    
    function updateSnapshots(uint givenDay)
        public
    {
        require(
            givenDay <= getCurrentOneDay(),
            "SS: Exceeded current day"
        );
        
        uint stakedAmount = 1e18;
        uint startDay = dailySnapshots.length-1; // last sealed day
        for (uint i = startDay; i<givenDay; i++)
        {
            uint sharesCount = 
                ((SHARE_MULTIPLIER_NUMERATOR + SHARE_MULTIPLIER_DENOMINATOR) * stakedAmount * SHARE_PRICE_DENORM) / 
                    (SHARE_MULTIPLIER_DENOMINATOR * dailySnapshots[i].sharePrice);
            uint inflationAmount = 
                (stakedAmount * CONTROLLED_APY * (dailySnapshots[i].totalShares + sharesCount)) / 
                    (sharesCount * DAYS_IN_A_YEAR * APY_DENORM);
                
            dailySnapshots[i].inflationAmount += inflationAmount;
            emit DailySnapshotSealed(i, dailySnapshots[i], mainToken.totalSupply());
            
            dailySnapshots.push(DailySnapshot(
                0,
                dailySnapshots[i].totalShares,
                dailySnapshots[i].totalStaked,
                dailySnapshots[i].sharePrice
            ));
        }
        
        uint startTenDay = tenDaysInterestPerShare.length-1;
        uint endTenDay = givenDay / 10;
        for(uint i = startTenDay; i<endTenDay; i++)
        {
            uint interestPerShare;
            for(uint j = i*10; j<(i+1)*10; j++)
            {
                if (dailySnapshots[j].totalShares == 0) continue;
                
                interestPerShare += 
                    (dailySnapshots[j].inflationAmount * INTEREST_PER_SHARE_DENORM) / dailySnapshots[j].totalShares;
            }
            tenDaysInterestPerShare[tenDaysInterestPerShare.length - 1] = interestPerShare;
            emit TenDaysInterestPerShareSealed(i, tenDaysInterestPerShare[i]);
            
            tenDaysInterestPerShare.push(0);
        }
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
        
        uint today = getCurrentOneDay();
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
            stakes[stakeId].owner,
            stakes[stakeId].stakedAmount, 
            stakes[stakeId].startDay,
            stakes[stakeId].lockedForXDays,
            sharesCount
        );
    }
    
    function endStake(
        uint stakeId,
        uint _bumpDays // TODO: remove on production
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
        
        bumpDays(_bumpDays); // TODO: remove on production
        updateAllSnapshots();
        
        uint today = getCurrentOneDay();
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
    
    function getDailySnapshotsLength()
        public
        view
        returns(uint)
    {
        return dailySnapshots.length;
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
        endDay = minOfTwoUints(endDay, dailySnapshots.length);
        
        uint startTen = stake.startDay/10 + 1;
        uint endBeforeFirstTen = startTen*10;
        for(uint i = stake.startDay; i<endBeforeFirstTen; i++)
        {
            if (dailySnapshots[i].totalShares == 0) continue;
            
            interest += (dailySnapshots[i].inflationAmount * sharesCount) / dailySnapshots[i].totalShares;
        }
        
        uint endTen = endDay/10;
        for(uint i = startTen; i<endTen; i++)
        {
            interest += (tenDaysInterestPerShare[i] * sharesCount) / INTEREST_PER_SHARE_DENORM;
        }
        
        uint startAfterLastTen = endDay - endDay % 10;
        for(uint i = startAfterLastTen; i<endDay; i++)
        {
            if (dailySnapshots[i].totalShares == 0) continue;
            
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
        require(
            dailySnapshots[stake.startDay].sharePrice > 0,
            "SS: Share price today is zero, wait for snapshot update"
        );
        
        uint numberOfDaysServed = givenDay == 0? stake.lockedForXDays: givenDay - stake.startDay;
        
        /*
            10yr - 2.5x
            1yr - 0.25x
            1d - 0.0006849x
        */
        uint sharesCount = 
            (stake.stakedAmount * SHARE_PRICE_DENORM) / dailySnapshots[stake.startDay].sharePrice +
            (SHARE_MULTIPLIER_NUMERATOR * numberOfDaysServed * stake.stakedAmount * SHARE_PRICE_DENORM) / 
                (SHARE_MULTIPLIER_DENOMINATOR * 10 * DAYS_IN_A_YEAR * dailySnapshots[stake.startDay].sharePrice);
        return sharesCount;
    }
    
    function bumpDays(uint numDays) // TODO: remove on production
        public
    {
        currentDay += numDays;
        updateAllSnapshots();
    }
    
    function getCurrentOneDay()
        public
        view
        returns (uint)
    {
        //return (block.timestamp - launchTimestamp) / 60;
        return currentDay; // TODO: remove on production
    }
    
    function getCurrentTenDay()
        public
        view
        returns (uint)
    {
        //return (block.timestamp - launchTimestamp) / 60;
        return currentDay/10; // TODO: remove on production
    }
    
    function getCurrentHundredDay()
        public
        view
        returns (uint)
    {
        //return (block.timestamp - launchTimestamp) / 60;
        return currentDay/100; // TODO: remove on production
    }
    
    function getCurrentThousandDay()
        public
        view
        returns (uint)
    {
        //return (block.timestamp - launchTimestamp) / 60;
        return currentDay/1000; // TODO: remove on production
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