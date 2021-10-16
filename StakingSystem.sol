// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.7;

import "./openzeppelin/access/AccessControlEnumerable.sol";

interface IDefiFactoryToken {
    
    function balanceOf(
        address account
    )
        external
        view
        returns (uint);
    
    function totalSupply()
        external
        view
        returns (uint);
        
    function mintHumanAddress(address to, uint desiredAmountToMint) external;

    function burnHumanAddress(address from, uint desiredAmountToBurn) external;
}

struct DailySnapshot {
    uint inflationAmount;
    uint totalShares;
    uint sharePrice;
}

struct Stake {
    address owner;
    uint stakedAmount;
    uint startDay;
    uint lockedForXDays;
    uint endDay;
}

struct StartStake {
    uint stakedAmount;
    uint lockedForXDays;
}

contract StakingSystem is AccessControlEnumerable {
    DailySnapshot[] public dailySnapshots;
    
    Stake[] public stakes;
    uint public totalStaked;
    
    uint constant CACHED_DAYS_INTEREST = 10;
    uint[] public cachedInterestPerShare;
    
    // TODO: 10days, 100 days, 1000 days snapshots
    // [["1000000000000000000000",10],["2000000000000000000000",20],["3000000000000000000000",30],["4000000000000000000000",40],["5000000000000000000000",100]]
    // [["6000000000000000000000",200]]
    // 0x123492a8E888Ca3fe8E31cb2e34872FE0ce5309F
    
    
    // TODO: update apy variables
    uint constant MINIMUM_DAYS_FOR_HIGH_PENALTY = 0;
    uint constant DAYS_IN_A_YEAR = 10;
    uint constant CONTROLLED_APY = 4e5; // 40%
    uint constant SHARE_PRICE_DENORM = 1e6;
    uint constant INTEREST_PER_SHARE_DENORM = 1e18;
    uint constant APY_DENORM = 1e6;
    uint constant END_STAKE_FROM = 7;
    uint constant END_STAKE_TO = 2*DAYS_IN_A_YEAR; // TODO: 5% per month penalty
    uint constant MINIMUM_STAKE_DAYS = 1;
    uint constant MAXIMUM_STAKE_DAYS = 100*DAYS_IN_A_YEAR;
    uint constant SHARE_MULTIPLIER_NUMERATOR = 5; // 5/2 = 250% bonus max
    uint constant SHARE_MULTIPLIER_DENOMINATOR = 2;
    uint constant SECONDS_IN_ONE_DAY = 600;
    
    IDefiFactoryToken mainToken = IDefiFactoryToken(
        0x7A7492a8e888Ca3fe8e31cB2E34872FE0CE5309f // TODO: change to deft token on production
    );
    
    uint public launchTimestamp;
    //uint currentDay = 2; // TODO: remove on production
    
    
    event StakeStarted(
        uint stakeId, 
        address owner, 
        uint stakedAmount, 
        uint startDay, 
        uint lockedForXDays, 
        uint sharesCount
    );
    event StakeEnded(
        uint stakeId, 
        uint endDay, 
        uint interest, 
        uint penalty
    );
    event StakeOwnerChanged(
        uint stakeId, 
        address newOwner
    );
    event StakeUpdated(
        uint stakeId, 
        uint lockedForXDays,
        uint sharesCount
    );
    
    event DailySnapshotSealed(
        uint sealedDay, 
        uint inflationAmount,
        uint totalShares,
        uint sharePrice,
        uint totalStaked,
        uint totalSupply
    );
    event CachedInterestPerShareSealed(
        uint sealedDay,
        uint sealedCachedDay, 
        uint cachedInterestPerShare
    );
    
    constructor() 
    {
        launchTimestamp = block.timestamp - 20 minutes; // TODO: remove on production
        
        dailySnapshots.push(DailySnapshot(
            0,
            0,
            SHARE_PRICE_DENORM
        ));
        dailySnapshots.push(DailySnapshot(
            0,
            0,
            SHARE_PRICE_DENORM
        ));
        
        cachedInterestPerShare.push(0);
        _setupRole(ROLE_ADMIN, msg.sender);
    }
    
    modifier onlyStakeOwners(uint stakeId)
    {
        require(
            msg.sender == stakes[stakeId].owner,
            "SS: Stake owner does not match"
        );
        _;
    }
    
    modifier onlyExistingStake(uint stakeId)
    {
        require(
            stakeId < stakes.length,
            "SS: Stake does not exist"
        );
        _;
    }
    
    modifier onlyActiveStake(uint stakeId)
    {
        require(
            stakes[stakeId].endDay == 0,
            "SS: Stake was already ended"
        );
        _;
    }
    
    function adminBurnAndAddToStakersInflation(address fromAddr, uint amountToBurn)
        public
        onlyRole(ROLE_ADMIN)
    {
        mainToken.burnHumanAddress(fromAddr, amountToBurn);
        
        uint today = getCurrentOneDay();
        dailySnapshots[today].inflationAmount += amountToBurn;
    }
    
    function bulkTransferOwnership(uint[] calldata stakeIds, address newOwner)
        public
    {
        for(uint i = 0; i<stakeIds.length; i++)
        {
            transferOwnership(stakeIds[i], newOwner);
        }
    }
    
    // 0xDc15Ca882F975c33D8f20AB3669D27195B8D87a6
    function transferOwnership(uint stakeId, address newOwner)
        public
        onlyStakeOwners(stakeId)
        onlyExistingStake(stakeId)
        onlyActiveStake(stakeId)
    {
        // TODO: check for bots
        
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
            emit DailySnapshotSealed(
                i,
                dailySnapshots[i].inflationAmount,
                dailySnapshots[i].totalShares,
                dailySnapshots[i].sharePrice,
                totalStaked,
                mainToken.totalSupply()
            );
            
            dailySnapshots.push(DailySnapshot(
                0,
                dailySnapshots[i].totalShares,
                dailySnapshots[i].sharePrice
            ));
        }
        
        uint startCachedDay = cachedInterestPerShare.length-1;
        uint endCachedDay = givenDay / CACHED_DAYS_INTEREST;
        for(uint i = startCachedDay; i<endCachedDay; i++)
        {
            uint interestPerShare;
            for(uint j = i*CACHED_DAYS_INTEREST; j<(i+1)*CACHED_DAYS_INTEREST; j++)
            {
                if (dailySnapshots[j].totalShares == 0) continue;
                
                interestPerShare += 
                    (dailySnapshots[j].inflationAmount * INTEREST_PER_SHARE_DENORM) / dailySnapshots[j].totalShares;
            }
            cachedInterestPerShare[cachedInterestPerShare.length - 1] = interestPerShare;
            emit CachedInterestPerShareSealed(
                i, // sealedDay
                cachedInterestPerShare.length - 1, // sealedCachedDay
                cachedInterestPerShare[i]
            );
            
            cachedInterestPerShare.push(0);
        }
    }
    
    function bulkStartStake(StartStake[] calldata startStakes)
        public
    {
        for(uint i; i<startStakes.length; i++)
        {
            startStake(startStakes[i]);
        }
    }
    
    function startStake(StartStake memory _startStake)
        public
        returns(uint stakeId)
    {
        // TODO: check for bots
        
        require(
            _startStake.stakedAmount > 0,
            "SS: StakedAmount has to be larger than zero"
        );
        require(
            _startStake.stakedAmount <= mainToken.balanceOf(msg.sender),
            "SS: StakedAmount exceeds balance"
        );
        require(
            _startStake.lockedForXDays >= MINIMUM_STAKE_DAYS,
            "SS: Stake must be locked for more than 1 days"
        );
        require(
            _startStake.lockedForXDays <= MAXIMUM_STAKE_DAYS,
            "SS: Stake must be locked for less than 100 years"
        );
        
        updateAllSnapshots();
        
        mainToken.burnHumanAddress(msg.sender, _startStake.stakedAmount);
        
        uint today = getCurrentOneDay();
        stakes.push(
            Stake(
                msg.sender,
                _startStake.stakedAmount,
                today,
                _startStake.lockedForXDays,
                0
            )
        );
        
        stakeId = stakes.length - 1;
        uint sharesCount = getSharesCountByStake(stakes[stakeId], 0);
        dailySnapshots[today].totalShares += sharesCount;
        totalStaked += _startStake.stakedAmount;
        
        emit StakeStarted(
            stakeId,
            stakes[stakeId].owner,
            stakes[stakeId].stakedAmount, 
            stakes[stakeId].startDay,
            stakes[stakeId].lockedForXDays,
            sharesCount
        );
        
        return stakeId;
    }
    
    function bulkEndStake(uint[] calldata stakeIds)
        public
    {
        for(uint i; i<stakeIds.length; i++)
        {
            endStake(stakeIds[i]/*, 0*/);
        }
    }
    
    function endStake(
        uint stakeId/*,
        uint _bumpDays*/ // TODO: remove on production
    )
        public
        onlyStakeOwners(stakeId)
        onlyExistingStake(stakeId)
        onlyActiveStake(stakeId)
    {
        //bumpDays(_bumpDays); // TODO: remove on production
        updateAllSnapshots();
        
        uint today = getCurrentOneDay();
        stakes[stakeId].endDay = today;
        
        mainToken.mintHumanAddress(msg.sender, stakes[stakeId].stakedAmount);
        
        uint interest;
        if (
                today < stakes[stakeId].startDay + stakes[stakeId].lockedForXDays
        ) { // Early end stake: Calculating interest similar to scrapeStake one
            Stake memory modifiedStakeToGetInterest = stakes[stakeId];
            modifiedStakeToGetInterest.lockedForXDays = today - stakes[stakeId].startDay;
            interest = getInterestByStake(modifiedStakeToGetInterest, today);
        } else { // Late or correct end stake
            interest = getInterestByStake(stakes[stakeId], today);
        }
        
        if (interest > 0)
        {
            mainToken.mintHumanAddress(msg.sender, interest);
        }
        
        uint penalty = getPenaltyByStake(stakes[stakeId], today, interest);
        if (penalty > 0) 
        {
            mainToken.burnHumanAddress(msg.sender, penalty);
            dailySnapshots[today].inflationAmount += penalty;
        }
        
        
        
        uint payout = stakes[stakeId].stakedAmount + interest - penalty;
        uint maxROI = maxOfTwoUints(
                (payout * SHARE_PRICE_DENORM) / stakes[stakeId].stakedAmount,
                dailySnapshots[today].sharePrice
            );
        if (maxROI > dailySnapshots[today].sharePrice) 
        {
           dailySnapshots[today].sharePrice = maxROI;
        }
        
        totalStaked -= stakes[stakeId].stakedAmount;
        dailySnapshots[today].totalShares -= getSharesCountByStake(stakes[stakeId], 0);
        
        emit StakeEnded(stakeId, today, interest, penalty);
    }
    
    function bulkScrapeStake(uint[] calldata stakeIds)
        public
    {
        for(uint i; i<stakeIds.length; i++)
        {
            scrapeStake(stakeIds[i]/*, 0*/);
        }
    }
    
    function scrapeStake(uint stakeId/*, uint _bumpDays*/)
        public
        onlyStakeOwners(stakeId)
        onlyExistingStake(stakeId)
        onlyActiveStake(stakeId)
    {
        
        /*
        100 days
        15 days scrapeStake
        15 days end stake
        85 days start stake
        
        */
        
        //bumpDays(_bumpDays); // TODO: remove on productio
        updateAllSnapshots();
        
        uint today = getCurrentOneDay();
        require(
            today > MINIMUM_DAYS_FOR_HIGH_PENALTY + stakes[stakeId].startDay,
            "SS: Scraping is available once in a day"
        );
        require(
            today < stakes[stakeId].startDay + stakes[stakeId].lockedForXDays,
            "SS: Scraping is available once while stake is In Progress status"
        );
        
        uint stakeAmount = stakes[stakeId].stakedAmount;
        uint lockedForXDays = stakes[stakeId].lockedForXDays;
        
        
        uint oldSharesCount = getSharesCountByStake(stakes[stakeId], 0);
        stakes[stakeId].lockedForXDays = today - stakes[stakeId].startDay;
        uint newSharesCount = getSharesCountByStake(stakes[stakeId], 0);
        
        dailySnapshots[today].totalShares = dailySnapshots[today].totalShares - oldSharesCount + newSharesCount;
        
        emit StakeUpdated(
            stakeId, 
            stakes[stakeId].lockedForXDays,
            newSharesCount
        );
        
        endStake(stakeId/*, 0*/);
        
        uint newLockedForXDays = lockedForXDays - stakes[stakeId].lockedForXDays;
        startStake(StartStake(stakeAmount, newLockedForXDays));
        
        // TODO: add event stake child created???
    }
    
    function getDailySnapshotsLength()
        public
        view
        returns(uint)
    {
        return dailySnapshots.length;
    }
    
    function getCachedInterestPerShareLength()
        public
        view
        returns(uint)
    {
        return cachedInterestPerShare.length;
    }
    
    function getInterestById(uint stakeId, uint givenDay)
        public
        view
        returns (uint)
    {
        return getInterestByStake(stakes[stakeId], givenDay);
    }
    
    function getInterestByStake(Stake memory stake, uint givenDay)
        public
        view
        returns (uint)
    {
        if (givenDay <= stake.startDay) return 0;
        
        uint interest;
        
        uint endDay = minOfTwoUints(givenDay, stake.startDay + stake.lockedForXDays);
        endDay = minOfTwoUints(endDay, dailySnapshots.length-1);
        
        uint sharesCount = getSharesCountByStake(stake, endDay);
        
        uint startCachedDay = stake.startDay/CACHED_DAYS_INTEREST + 1; 
        uint endBeforeFirstCachedDay = minOfTwoUints(endDay, startCachedDay*CACHED_DAYS_INTEREST); 
        for(uint i = stake.startDay; i<endBeforeFirstCachedDay; i++)
        {
            if (dailySnapshots[i].totalShares == 0) continue;
            
            interest += (dailySnapshots[i].inflationAmount * sharesCount) / dailySnapshots[i].totalShares;
        }
        
        uint endCachedDay = endDay/CACHED_DAYS_INTEREST; 
        for(uint i = startCachedDay; i<endCachedDay; i++)
        {
            interest += (cachedInterestPerShare[i] * sharesCount) / INTEREST_PER_SHARE_DENORM;
        }
        
        uint startAfterLastCachedDay = endDay - endDay % CACHED_DAYS_INTEREST;
        if (startAfterLastCachedDay > stake.startDay) // do not double iterate if numberOfDaysServed < CACHED_DAYS_INTEREST 
        {
            for(uint i = startAfterLastCachedDay; i<endDay; i++)
            {
                if (dailySnapshots[i].totalShares == 0) continue;
                
                interest += (dailySnapshots[i].inflationAmount * sharesCount) / dailySnapshots[i].totalShares;
            }
        }
        
        return interest;
    }
    
    function getPenaltyById(uint stakeId, uint givenDay, uint interest)
        public
        view
        returns (uint)
    {
        return getPenaltyByStake(stakes[stakeId], givenDay, interest);
    }
    
    function getPenaltyByStake(Stake memory stake, uint givenDay, uint interest)
        public
        pure
        returns (uint)
    {
        /*
        0 -- 7 days served => 10% principal back
        7 days -- 50% served --> 10-90% principal back
        50-100% served --> 90-100% principal back
        100% + 30 days --> 100% principal back
        100% + 30 days -- 100% + 30 days + 30*20 days --> 100-10% (principal+interest) back
        > 100% + 30 days + 30*20 days --> 10% (principal+interest) back
        */
        if (givenDay <= stake.startDay) return 0;
        
        uint penalty;
        uint howManyDaysServed = givenDay - stake.startDay;
        
        if (howManyDaysServed <= MINIMUM_DAYS_FOR_HIGH_PENALTY) // Stake just started or less than 7 days passed)
        {
            penalty = (stake.stakedAmount * 9) / 10;
        } else if (howManyDaysServed <= stake.lockedForXDays / 2) 
        {
            // 90-10%
            penalty = 
                (stake.stakedAmount * 9) / 10 - 
                (stake.stakedAmount * 8 * (howManyDaysServed - MINIMUM_DAYS_FOR_HIGH_PENALTY)) / (5 * (stake.lockedForXDays - 2));
        } else if (howManyDaysServed <= stake.lockedForXDays) {
            // 10-0%
            penalty = 
                stake.stakedAmount / 10 - 
                (stake.stakedAmount * (2*howManyDaysServed - stake.lockedForXDays)) / (10 * stake.lockedForXDays);
        } else if (howManyDaysServed <= stake.lockedForXDays + END_STAKE_FROM)
        {
            penalty = 0;
        } else if (howManyDaysServed <= stake.lockedForXDays + END_STAKE_FROM + END_STAKE_TO) {
            // 0-90% + interest
            penalty = 
                ((stake.stakedAmount + interest) * 9 * (howManyDaysServed - stake.lockedForXDays - END_STAKE_FROM)) / (10 * END_STAKE_TO);
        } else // if (howManyDaysServed > stake.lockedForXDays + END_STAKE_FROM + END_STAKE_TO)
        {
            // 90% + interest
            penalty = ((stake.stakedAmount + interest) * 9) / 10;
        } 
        
        return penalty;
    }
    
    function getSharesCountById(uint stakeId, uint givenDay)
        public
        view
        returns(uint)
    {
        return getSharesCountByStake(stakes[stakeId], givenDay);
    }
    
    function getSharesCountByStake(Stake memory stake, uint givenDay)
        public
        view
        returns (uint)
    {
        if (0 < givenDay && givenDay <= stake.startDay) return 0;
        
        require(
            dailySnapshots[stake.startDay].sharePrice > 0,
            "SS: Share price on start day is zero, wait for snapshot update"
        );
        
        uint numberOfDaysServed = givenDay == 0? stake.lockedForXDays: givenDay - stake.startDay;
        require(
            numberOfDaysServed >= 0,
            "SS: NumberOfDaysServed must be larger than zero"
        );
        
        
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
    
    /*function bumpDays(uint numDays) // TODO: remove on production
        public
    {
        currentDay += numDays;
        updateAllSnapshots();
    }*/
    
    function getCurrentOneDay()
        public
        view
        returns (uint)
    {
        return (block.timestamp - launchTimestamp) / SECONDS_IN_ONE_DAY;
        //return currentDay; // TODO: remove on production
    }
    
    function getCurrentCachedPerShareDay()
        public
        view
        returns (uint)
    {
        return (block.timestamp - launchTimestamp) / SECONDS_IN_ONE_DAY;
        //return currentDay/CACHED_DAYS_INTEREST; // TODO: remove on production
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
