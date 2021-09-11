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
    mapping(uint => DailySnapshot) public snapshots;
    mapping(address => Stake[]) public stakers;
    
    uint constant SHARE_PRICE_DENORM = 1e6;
    
    IDefiFactoryToken mainToken = IDefiFactoryToken(0x7A7492a8e888Ca3fe8e31cB2E34872FE0CE5309f);
    
    uint launchTimestamp;
    constructor() 
    {
        launchTimestamp = block.timestamp - 2 minutes;
        
        snapshots[0] = DailySnapshot(
            true,
            0,
            mainToken.totalSupply(),
            0,
            0,
            SHARE_PRICE_DENORM
        );
        
        snapshots[1] = DailySnapshot(
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
        uint startDat = latestSealedSnapshotDay + 1;
        for (uint i = startDat; i<givenDay; i++)
        {
            if (snapshots[i].isSealed) continue;
            
            uint inflationAmount = 
                snapshots[i].inflationAmount + 
                    ((snapshots[i].totalSupply + snapshots[i].totalStaked) * 10) / 100;
                
            snapshots[i] = DailySnapshot(
                true,
                inflationAmount,
                snapshots[i].totalSupply,
                snapshots[i].totalShares,
                snapshots[i].totalStaked,
                snapshots[i].sharePrice
            );
            
            snapshots[i+1] = DailySnapshot(
                false,
                0,
                mainToken.totalSupply(),
                snapshots[i].totalShares,
                snapshots[i].totalStaked,
                snapshots[i].sharePrice
            );
        }
        
        latestSealedSnapshotDay = 
            givenDay > 0 && snapshots[givenDay - 1].isSealed? givenDay - 1: latestSealedSnapshotDay;
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
            0 < lockedForXDays && lockedForXDays < 100000,
            "SS: Wrong amount of days specified"
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
        snapshots[today].totalShares += sharesCount;
        snapshots[today].totalStaked += stakedAmount;
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
            stakers[msg.sender][stakePosition].endDay > 0,
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
            
            snapshots[today].inflationAmount += penalty + interest;
        } else if (interest > 0)
        {
            payout = stake.stakedAmount + interest;
            mainToken.mintHumanAddress(msg.sender, interest);
        }
        
        uint roi = (payout * SHARE_PRICE_DENORM) / stake.stakedAmount;
        if (roi > snapshots[today].sharePrice)
        {
            snapshots[today].sharePrice = roi;
        }
        
        snapshots[today].totalShares -= getSharesCount(msg.sender, stakePosition, 0);
        snapshots[today].totalStaked -= stake.stakedAmount;
    }
    
    function getInterest(address stakerAddress, uint stakePosition, uint givenDay)
        public
        view
        returns (uint)
    {
        uint interest;
        Stake memory stake = stakers[stakerAddress][stakePosition];
        uint sharesCount = getSharesCount(stakerAddress, stakePosition, givenDay);
        
        givenDay = 
            givenDay > stake.startDay + stake.lockedForXDays? stake.startDay + stake.lockedForXDays: givenDay;
        for(uint i = stake.startDay; i<givenDay; i++)
        {
            interest += (snapshots[i].inflationAmount * sharesCount) / snapshots[i].totalShares;
        }
        
        return interest;
    }
    
    function getPrincipalPenalty(address stakerAddress, uint stakePosition, uint givenDay)
        public
        view
        returns (uint)
    {
        /*
        0-50% served --> 0-90% principal back
        50-100% served --> 90-100% principal back
        100% + 14 days --> 100% principal back
        100% + 14 days + 365 days --> 0% principal back
        */
        uint penalty;
        Stake memory stake = stakers[stakerAddress][stakePosition];
        uint howManyDaysServed = givenDay - stake.startDay;
        if (howManyDaysServed == 0)
        {
            penalty = 0;
        } else if (stake.lockedForXDays / 2 < howManyDaysServed && howManyDaysServed <= stake.lockedForXDays)
        {
            penalty = ((howManyDaysServed - stake.lockedForXDays/2) * 10 * stake.stakedAmount * 2) / (100 * stake.lockedForXDays);
        } else if (howManyDaysServed <= stake.lockedForXDays / 2)
        {
            penalty = (howManyDaysServed * 90 * stake.stakedAmount * 2) / (100 * stake.lockedForXDays);
        } else if (
            stake.lockedForXDays + 14 < howManyDaysServed && 
            howManyDaysServed <= stake.lockedForXDays + 14 + 365
        )
        {
            // TODO: add penalty formula
            penalty = (howManyDaysServed - stake.lockedForXDays - 14);
        } else if (howManyDaysServed > stake.lockedForXDays + 14 + 365)
        {
            penalty = stake.stakedAmount;
        }
        
        return penalty;
    }
    
    function getSharesCount(address stakerAddress, uint stakePosition, uint givenDay)
        public
        view
        returns (uint)
    {
        Stake memory stake = stakers[stakerAddress][stakePosition];
        DailySnapshot memory dayBeforeStartDaySnapshot = snapshots[stake.startDay-1];
        
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
    
    function getCurrentDay()
        public
        view
        returns (uint)
    {
        return (block.timestamp - launchTimestamp) / 60;
    }
    
}