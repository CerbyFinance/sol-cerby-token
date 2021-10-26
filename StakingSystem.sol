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
    uint maxSharesCountOnStartStake;
}

struct StartStake {
    uint stakedAmount;
    uint lockedForXDays;
}

struct Settings {
    uint MINIMUM_DAYS_FOR_HIGH_PENALTY;
    uint CONTROLLED_APY;
    uint SMALLER_PAYS_BETTER_BONUS;
    uint LONGER_PAYS_BETTER_BONUS;
    uint END_STAKE_FROM;
    uint END_STAKE_TO;
    uint MINIMUM_STAKE_DAYS;
    uint MAXIMUM_STAKE_DAYS;
}

contract StakingSystem is AccessControlEnumerable {
    DailySnapshot[] public dailySnapshots;
    uint[] public cachedInterestPerShare;
    
    Stake[] public stakes;
    
    Settings public settings;
    
    
    // [["1000000000000000000000",1],["2000000000000000000000",2],["3000000000000000000000",3],["10000000000000000000000",365],["10000000000000000000000",730],["10000000000000000000000",1095],["10000000000000000000000",1460],["10000000000000000000000",1825],["10000000000000000000000",2190],["10000000000000000000000",2555],["10000000000000000000000",2920],["10000000000000000000000",3650],["10000000000000000000000",7300]]
    // [["6000000000000000000000",3650]]
    // 0x123492a8E888Ca3fe8E31cb2e34872FE0ce5309F
    
    uint constant MINIMUM_SMALLER_PAYS_BETTER = 1000 * 1e18; // 1000 deft
    uint constant MAXIMUM_SMALLER_PAYS_BETTER = 1000000 * 1e18; // 1 million deft
    uint constant CACHED_DAYS_INTEREST = 100;
    uint constant DAYS_IN_ONE_YEAR = 365;
    uint constant SHARE_PRICE_DENORM = 1e18;
    uint constant INTEREST_PER_SHARE_DENORM = 1e18;
    uint constant APY_DENORM = 1e6;
    uint constant SECONDS_IN_ONE_DAY = 60*3;
    
    IDefiFactoryToken mainToken = IDefiFactoryToken(
        0xe4DFe0FC73A9B9105Ed0422ba66084b47A32499F // TODO: change to deft token on production
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
    
    event NewMaxSharePriceReached(
        uint newSharePrice
    );
    
    constructor() 
    {
        settings.MINIMUM_DAYS_FOR_HIGH_PENALTY = 0;
        settings.CONTROLLED_APY = 4e5; // 40%
        settings.END_STAKE_FROM = 30;
        settings.END_STAKE_TO = 2*DAYS_IN_ONE_YEAR; // TODO: 5% per month penalty
        settings.MINIMUM_STAKE_DAYS = 1;
        settings.MAXIMUM_STAKE_DAYS = 100*DAYS_IN_ONE_YEAR;
        settings.LONGER_PAYS_BETTER_BONUS = 3e6; // 3e6/1e6 = 300% shares bonus max
        settings.SMALLER_PAYS_BETTER_BONUS = 25e4; // 25e4/1e6 = 25% shares bonus max
        
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
        emit NewMaxSharePriceReached(SHARE_PRICE_DENORM);
        
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
        
        uint startDay = dailySnapshots.length-1; // last sealed day
        if (startDay == givenDay) return;
        
        for (uint i = startDay; i<givenDay; i++)
        {
            uint currentSnapshotIndex = dailySnapshots.length > i? i: dailySnapshots.length-1;
            uint sharesCount =
                ((settings.LONGER_PAYS_BETTER_BONUS + APY_DENORM) * SHARE_PRICE_DENORM) / 
                    (APY_DENORM * dailySnapshots[currentSnapshotIndex].sharePrice);
            uint inflationAmount = 
                (settings.CONTROLLED_APY * (dailySnapshots[currentSnapshotIndex].totalShares + sharesCount)) / 
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
                getTotalTokensStaked(),
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
        
        mainToken.transferCustom(msg.sender, address(this), _startStake.stakedAmount);
        
        uint today = getCurrentDaySinceLaunch();
        Stake memory stake = Stake(
            msg.sender,
            _startStake.stakedAmount,
            today,
            _startStake.lockedForXDays,
            0,
            0
        );
        stake.maxSharesCountOnStartStake = getSharesCountByStake(stake, 0);
        
        stakes.push(
            stake
        );
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
        
        mainToken.transferCustom(address(this), msg.sender, stakes[stakeId].stakedAmount);
        
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
        uint ROI = (payout * SHARE_PRICE_DENORM) / stakes[stakeId].stakedAmount;
        if (ROI > dailySnapshots[today].sharePrice) 
        {
           dailySnapshots[today].sharePrice = ROI;
           emit NewMaxSharePriceReached(ROI);
        }
        
        dailySnapshots[today].totalShares -= stakes[stakeId].maxSharesCountOnStartStake;
        
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
    
    function scrapeStake(
        uint stakeId/*, 
        uint _bumpDays*/  // TODO: remove on production
    )
        public
        onlyStakeOwners(stakeId)
        onlyExistingStake(stakeId)
        onlyActiveStake(stakeId)
    {
        //bumpDays(_bumpDays); // TODO: remove on production
        updateAllSnapshots();
        
        uint today = getCurrentDaySinceLaunch();
        require(
            today > stakes[stakeId].startDay,
            "SS: Scraping is available once in 1 day"
        );
        require(
            today < stakes[stakeId].startDay + stakes[stakeId].lockedForXDays,
            "SS: Scraping is available once while stake is In Progress status"
        );
        
        uint oldLockedForXDays = stakes[stakeId].lockedForXDays;
        uint oldSharesCount = stakes[stakeId].maxSharesCountOnStartStake;
        
        stakes[stakeId].lockedForXDays = today - stakes[stakeId].startDay;
        uint newSharesCount = getSharesCountByStake(stakes[stakeId], 0);
        
        dailySnapshots[today].totalShares = dailySnapshots[today].totalShares - oldSharesCount + newSharesCount;
        stakes[stakeId].maxSharesCountOnStartStake = newSharesCount;
        
        emit StakeUpdated(
            stakeId, 
            stakes[stakeId].lockedForXDays,
            newSharesCount
        );
        
        //endStake(stakeId, 0); // TODO: remove on production
        endStake(stakeId);
        
        uint newLockedForXDays = oldLockedForXDays - stakes[stakeId].lockedForXDays;
        startStake(StartStake(stakes[stakeId].stakedAmount, newLockedForXDays));
    }
    
    function getTotalTokensStaked()
        public
        view
        returns(uint)
    {
        return IDefiFactoryToken(mainToken).balanceOf(address(this));
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
        
        uint sharesCount = getSharesCountByStake(stake, givenDay);
        uint startCachedDay = stake.startDay/CACHED_DAYS_INTEREST + 1;
        uint endBeforeFirstCachedDay = minOfTwoUints(endDay, startCachedDay*CACHED_DAYS_INTEREST); 
        for(uint i = stake.startDay; i<endBeforeFirstCachedDay; i++)
        {
            if (dailySnapshots[i].totalShares == 0) continue;
            
            interest += (dailySnapshots[i].inflationAmount * sharesCount) / dailySnapshots[i].totalShares;
        }
        
        // TODO: make two contracts
        // TODO: one with CACHED_DAYS_INTEREST = 10, second with CACHED_DAYS_INTEREST = 1000
        // TODO: compare interest formula for both
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
        numberOfDaysServed = minOfTwoUints(numberOfDaysServed, 10*DAYS_IN_ONE_YEAR);
        
        /*
            10yr - 2.5x
            1yr - 0.25x
            1d - 0.0006849x
        */
        uint initialSharesCount = 
            (stake.stakedAmount * SHARE_PRICE_DENORM) / dailySnapshots[stake.startDay].sharePrice;
        uint longerPaysBetterSharesCount =
            (settings.LONGER_PAYS_BETTER_BONUS * numberOfDaysServed * stake.stakedAmount * SHARE_PRICE_DENORM) / 
                (APY_DENORM * 10 * DAYS_IN_ONE_YEAR * dailySnapshots[stake.startDay].sharePrice);
        uint smallerPaysBetterSharesCountMultiplier;
        if (stake.stakedAmount <= MINIMUM_SMALLER_PAYS_BETTER)
        {
            smallerPaysBetterSharesCountMultiplier = APY_DENORM + settings.SMALLER_PAYS_BETTER_BONUS;
        } else if (
            MINIMUM_SMALLER_PAYS_BETTER < stake.stakedAmount &&
            stake.stakedAmount < MAXIMUM_SMALLER_PAYS_BETTER
        ) {
            smallerPaysBetterSharesCountMultiplier = 
                APY_DENORM + 
                    (settings.SMALLER_PAYS_BETTER_BONUS * (MAXIMUM_SMALLER_PAYS_BETTER - stake.stakedAmount)) /
                        (MAXIMUM_SMALLER_PAYS_BETTER - MINIMUM_SMALLER_PAYS_BETTER);
        } else // MAXIMUM_SMALLER_PAYS_BETTER >= stake.stakedAmount
        {
            smallerPaysBetterSharesCountMultiplier = APY_DENORM;
        }
        uint sharesCount = 
            ((initialSharesCount + longerPaysBetterSharesCount) * smallerPaysBetterSharesCountMultiplier) / 
                APY_DENORM;
                
        return sharesCount;
    }
    
    /*uint currentDay = 1; // TODO: remove on production
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
