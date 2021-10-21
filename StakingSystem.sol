// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.9;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/IDefiFactoryTokenMinterBurner.sol";

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
    uint sharesCount;
}

struct StartStake {
    uint stakedAmount;
    uint lockedForXDays;
}

struct Settings {
    uint MINIMUM_DAYS_FOR_HIGH_PENALTY;
    uint CONTROLLED_APY;
    uint END_STAKE_FROM;
    uint END_STAKE_TO;
    uint MINIMUM_STAKE_DAYS;
    uint MAXIMUM_STAKE_DAYS;
    uint SHARE_MULTIPLIER_NUMERATOR;
    uint SHARE_MULTIPLIER_DENOMINATOR;
}

contract StakingSystem is AccessControlEnumerable {
    DailySnapshot[] public dailySnapshots;
    uint[] public cachedInterestPerShare;
    
    Stake[] public stakes;
    uint public totalStaked;
    
    Settings public settings;
    
    
    // [["1000000000000000000000",1],["2000000000000000000000",2],["3000000000000000000000",3],["4000000000000000000000",4],["5000000000000000000000",10]]
    // [["6000000000000000000000",200]]
    // 0x123492a8E888Ca3fe8E31cb2e34872FE0ce5309F
    
    
    uint constant CACHED_DAYS_INTEREST = 100;
    uint constant DAYS_IN_ONE_YEAR = 365;
    uint constant SHARE_PRICE_DENORM = 1e18;
    uint constant INTEREST_PER_SHARE_DENORM = 1e18;
    uint constant APY_DENORM = 1e6;
    uint constant SECONDS_IN_ONE_DAY = 600;
    
    IDefiFactoryToken mainToken = IDefiFactoryToken(
        0x7A7492a8e888Ca3fe8e31cB2E34872FE0CE5309f // TODO: change to deft token on production
    );
    
    uint public launchTimestamp;
    
    
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
    
    event SettingsUpdated(
        Settings Settings
    );
    
    constructor() 
    {
        settings.MINIMUM_DAYS_FOR_HIGH_PENALTY = 0;
        settings.CONTROLLED_APY = 4e5; // 40%
        settings.END_STAKE_FROM = 30;
        settings.END_STAKE_TO = 2*DAYS_IN_ONE_YEAR; // TODO: 5% per month penalty
        settings.MINIMUM_STAKE_DAYS = 1;
        settings.MAXIMUM_STAKE_DAYS = 100*DAYS_IN_ONE_YEAR;
        settings.SHARE_MULTIPLIER_NUMERATOR = 300; // 300/100 = 300% shares bonus max
        settings.SHARE_MULTIPLIER_DENOMINATOR = 100;
        
        launchTimestamp = block.timestamp; // TODO: remove on production
        
        dailySnapshots.push(DailySnapshot(
            0,
            0,
            SHARE_PRICE_DENORM
        ));
        emit DailySnapshotSealed(
            0,
            0,
            0,
            SHARE_PRICE_DENORM,
            0,
            mainToken.totalSupply()
        );
        dailySnapshots.push(DailySnapshot(
            0,
            0,
            SHARE_PRICE_DENORM
        ));
        cachedInterestPerShare.push(0);
        
        updateAllSnapshots();
        
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
    
    function adminUpdateSettings(Settings calldata _settings)
        public
        onlyRole(ROLE_ADMIN)
    {
        settings = _settings;
        
        emit SettingsUpdated(_settings);
    }
    
    function adminBurnAndAddToStakersInflation(address fromAddr, uint amountToBurn)
        public
        onlyRole(ROLE_ADMIN)
    {
        updateAllSnapshots();
        
        mainToken.burnHumanAddress(fromAddr, amountToBurn);
        
        uint today = getCurrentDaySinceLaunch();
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
        
        updateAllSnapshots();
        
        stakes[stakeId].owner = newOwner;
        emit StakeOwnerChanged(stakeId, newOwner);
    }
    
    function updateAllSnapshots()
        public
    {
        updateSnapshots(getCurrentDaySinceLaunch());
    }
    
    function updateSnapshots(uint givenDay)
        public
    {
        require(
            givenDay <= getCurrentDaySinceLaunch(),
            "SS: Exceeded current day"
        );
        
        uint stakedAmount = 1e18;
        uint startDay = dailySnapshots.length-1; // last sealed day
        if (startDay == givenDay) return;
        
        for (uint i = startDay; i<givenDay; i++)
        {
            uint currentSnapshotIndex = dailySnapshots.length > i? i: dailySnapshots.length-1;
            uint sharesCount = 
                ((settings.SHARE_MULTIPLIER_NUMERATOR + settings.SHARE_MULTIPLIER_DENOMINATOR) * stakedAmount * SHARE_PRICE_DENORM) / 
                    (settings.SHARE_MULTIPLIER_DENOMINATOR * dailySnapshots[currentSnapshotIndex].sharePrice);
            uint inflationAmount = 
                (stakedAmount * settings.CONTROLLED_APY * (dailySnapshots[currentSnapshotIndex].totalShares + sharesCount)) / 
                    (sharesCount * DAYS_IN_ONE_YEAR * APY_DENORM);
            
            if (dailySnapshots.length > i)
            {
                dailySnapshots[currentSnapshotIndex].inflationAmount += inflationAmount;
            } else
            {
                dailySnapshots.push(DailySnapshot(
                    inflationAmount,
                    dailySnapshots[currentSnapshotIndex].totalShares,
                    dailySnapshots[currentSnapshotIndex].sharePrice
                ));
            }
            emit DailySnapshotSealed(
                i,
                dailySnapshots[currentSnapshotIndex].inflationAmount,
                dailySnapshots[currentSnapshotIndex].totalShares,
                dailySnapshots[currentSnapshotIndex].sharePrice,
                totalStaked,
                mainToken.totalSupply()
            );
        }
        
        if (dailySnapshots.length == givenDay)
        {
            dailySnapshots.push(DailySnapshot(
                0,
                dailySnapshots[givenDay-1].totalShares,
                dailySnapshots[givenDay-1].sharePrice
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
            
            if (cachedInterestPerShare.length > i)
            {
                cachedInterestPerShare[cachedInterestPerShare.length - 1] = interestPerShare;
            } else {
                cachedInterestPerShare.push(0);
            }
            emit CachedInterestPerShareSealed(
                i, // sealedDay
                cachedInterestPerShare.length - 1, // sealedCachedDay
                cachedInterestPerShare[i]
            );
        }
        if (cachedInterestPerShare.length == endCachedDay)
        {
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
        require(
            _startStake.stakedAmount > 0,
            "SS: StakedAmount has to be larger than zero"
        );
        require(
            _startStake.stakedAmount <= mainToken.balanceOf(msg.sender),
            "SS: StakedAmount exceeds balance"
        );
        require(
            _startStake.lockedForXDays >= settings.MINIMUM_STAKE_DAYS,
            "SS: Stake must be locked for more than min days"
        );
        require(
            _startStake.lockedForXDays <= settings.MAXIMUM_STAKE_DAYS,
            "SS: Stake must be locked for less than max years"
        );
        
        updateAllSnapshots();
        
        mainToken.burnHumanAddress(msg.sender, _startStake.stakedAmount);
        
        uint today = getCurrentDaySinceLaunch();
        Stake memory stake = Stake(
            msg.sender,
            _startStake.stakedAmount,
            today,
            _startStake.lockedForXDays,
            0,
            0
        );
        stake.sharesCount = getSharesCountByStake(stake, 0);
        
        stakes.push(
            stake
        );
        
        stakeId = stakes.length - 1;
        dailySnapshots[today].totalShares += stake.sharesCount;
        totalStaked += _startStake.stakedAmount;
        
        emit StakeStarted(
            stakeId,
            stakes[stakeId].owner,
            stakes[stakeId].stakedAmount, 
            stakes[stakeId].startDay,
            stakes[stakeId].lockedForXDays,
            stake.sharesCount
        );
        
        return stakeId;
    }
    
    function bulkEndStake(uint[] calldata stakeIds)
        public
    {
        for(uint i; i<stakeIds.length; i++)
        {
            //endStake(stakeIds[i], 0); // TODO: remove on production
            endStake(stakeIds[i]);
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
        
        uint today = getCurrentDaySinceLaunch();
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
        dailySnapshots[today].totalShares -= stakes[stakeId].sharesCount;
        
        emit StakeEnded(stakeId, today, interest, penalty);
    }
    
    function bulkScrapeStake(uint[] calldata stakeIds)
        public
    {
        for(uint i; i<stakeIds.length; i++)
        {
            //scrapeStake(stakeIds[i], 0); // TODO: remove on production
            scrapeStake(stakeIds[i]);
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
        
        uint today = getCurrentDaySinceLaunch();
        require(
            today > settings.MINIMUM_DAYS_FOR_HIGH_PENALTY + stakes[stakeId].startDay,
            "SS: Scraping is available once in MINIMUM_DAYS_FOR_HIGH_PENALTY"
        );
        require(
            today < stakes[stakeId].startDay + stakes[stakeId].lockedForXDays,
            "SS: Scraping is available once while stake is In Progress status"
        );
        
        uint stakeAmount = stakes[stakeId].stakedAmount;
        uint lockedForXDays = stakes[stakeId].lockedForXDays;
        
        
        uint oldSharesCount = stakes[stakeId].sharesCount;
        stakes[stakeId].lockedForXDays = today - stakes[stakeId].startDay;
        stakes[stakeId].sharesCount = getSharesCountByStake(stakes[stakeId], 0);
        
        dailySnapshots[today].totalShares = dailySnapshots[today].totalShares - oldSharesCount + stakes[stakeId].sharesCount;
        
        emit StakeUpdated(
            stakeId, 
            stakes[stakeId].lockedForXDays,
            stakes[stakeId].sharesCount
        );
        
        //endStake(stakeId, 0); // TODO: remove on production
        endStake(stakeId);
        
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
    
    function getStakesLength()
        public
        view
        returns(uint)
    {
        return stakes.length;
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
        endDay = minOfTwoUints(endDay, dailySnapshots.length); // TODO: correct???
        
        uint startCachedDay = stake.startDay/CACHED_DAYS_INTEREST + 1; 
        uint endBeforeFirstCachedDay = minOfTwoUints(endDay, startCachedDay*CACHED_DAYS_INTEREST); 
        for(uint i = stake.startDay; i<endBeforeFirstCachedDay; i++)
        {
            if (dailySnapshots[i].totalShares == 0) continue;
            
            interest += (dailySnapshots[i].inflationAmount * stake.sharesCount) / dailySnapshots[i].totalShares;
        }
        
        // TODO: make two contracts
        // TODO: one with CACHED_DAYS_INTEREST = 10, second with CACHED_DAYS_INTEREST = 1000
        // TODO: compare interest formula for both
        uint endCachedDay = endDay/CACHED_DAYS_INTEREST; 
        for(uint i = startCachedDay; i<endCachedDay; i++)
        {
            interest += (cachedInterestPerShare[i] * stake.sharesCount) / INTEREST_PER_SHARE_DENORM;
        }
        
        uint startAfterLastCachedDay = endDay - endDay % CACHED_DAYS_INTEREST;
        if (startAfterLastCachedDay > stake.startDay) // do not double iterate if numberOfDaysServed < CACHED_DAYS_INTEREST 
        {
            for(uint i = startAfterLastCachedDay; i<endDay; i++)
            {
                if (dailySnapshots[i].totalShares == 0) continue;
                
                interest += (dailySnapshots[i].inflationAmount * stake.sharesCount) / dailySnapshots[i].totalShares;
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
        view
        returns (uint)
    {
        /*
        0 -- 0 days served => 0% principal back
        0 days -- 100% served --> 0-100% principal back
        100% + 30 days --> 100% principal back
        100% + 30 days -- 100% + 30 days + 30*20 days --> 100-10% (principal+interest) back
        > 100% + 30 days + 30*20 days --> 10% (principal+interest) back
        */
        uint penalty;
        uint howManyDaysServed = givenDay > stake.startDay? givenDay - stake.startDay: 0;
        uint riskAmount = stake.stakedAmount + interest;
        
        if (howManyDaysServed <= settings.MINIMUM_DAYS_FOR_HIGH_PENALTY) // Stake just started or less than 7 days passed)
        {
            penalty = riskAmount; // 100%
        } else if (howManyDaysServed <= stake.lockedForXDays) 
        {
            // 100-0%
            penalty = 
                (riskAmount * (stake.lockedForXDays - howManyDaysServed)) / (stake.lockedForXDays - settings.MINIMUM_DAYS_FOR_HIGH_PENALTY);
        } else if (howManyDaysServed <= stake.lockedForXDays + settings.END_STAKE_FROM)
        {
            penalty = 0;
        } else if (howManyDaysServed <= stake.lockedForXDays + settings.END_STAKE_FROM + settings.END_STAKE_TO) {
            // 0-90%
            penalty = 
                (riskAmount * 9 * (howManyDaysServed - stake.lockedForXDays - settings.END_STAKE_FROM)) / (10 * settings.END_STAKE_TO);
        } else // if (howManyDaysServed > stake.lockedForXDays + settings.END_STAKE_FROM + settings.END_STAKE_TO)
        {
            // 90%
            penalty = (riskAmount * 9) / 10;
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
        uint numberOfDaysServed;
        if (givenDay == 0)
        {
            numberOfDaysServed = stake.lockedForXDays;
        } else if (givenDay > stake.startDay)
        {
            numberOfDaysServed = givenDay - stake.startDay;
        } else // givenDay > 0 && givenDay < stake.startDay
        {
            return 0;
        }
        
        numberOfDaysServed = minOfTwoUints(numberOfDaysServed, 10 * DAYS_IN_ONE_YEAR);
        
        /*
            10yr - 2.5x
            1yr - 0.25x
            1d - 0.0006849x
        */
        uint sharesCount = 
            (stake.stakedAmount * SHARE_PRICE_DENORM) / dailySnapshots[stake.startDay].sharePrice +
            (settings.SHARE_MULTIPLIER_NUMERATOR * numberOfDaysServed * stake.stakedAmount * SHARE_PRICE_DENORM) / 
                (settings.SHARE_MULTIPLIER_DENOMINATOR * 10 * DAYS_IN_ONE_YEAR * dailySnapshots[stake.startDay].sharePrice);
        return sharesCount;
    }
    
    /*uint currentDay = 2; // TODO: remove on production
    function bumpDays(uint numDays) // TODO: remove on production
        public
    {
        currentDay += numDays;
        updateAllSnapshots();
    }*/
    
    function getCurrentDaySinceLaunch()
        public
        view
        returns (uint)
    {
        return block.timestamp / SECONDS_IN_ONE_DAY - launchTimestamp / SECONDS_IN_ONE_DAY + 1;
        //return currentDay; // TODO: remove on production
    }
    
    function getCurrentCachedPerShareDay()
        public
        view
        returns (uint)
    {
        return getCurrentDaySinceLaunch() / CACHED_DAYS_INTEREST;
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
