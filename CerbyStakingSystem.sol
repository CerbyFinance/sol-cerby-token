// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.10;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/ICerbyTokenMinterBurner.sol";
import "./interfaces/ICerbyBotDetection.sol";

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

contract CerbyStakingSystem is AccessControlEnumerable {
    DailySnapshot[] public dailySnapshots;
    uint[] public cachedInterestPerShare;
    
    Stake[] public stakes;
    Settings public settings;
    
    uint constant CERBY_BOT_DETECTION_CONTRACT_ID = 3;
    uint constant MINIMUM_SMALLER_PAYS_BETTER = 1000 * 1e18; // 1k CERBY
    uint constant MAXIMUM_SMALLER_PAYS_BETTER = 1000000 * 1e18; // 1M CERBY
    uint constant CACHED_DAYS_INTEREST = 100;
    uint constant DAYS_IN_ONE_YEAR = 365;
    uint constant SHARE_PRICE_DENORM = 1e18;
    uint constant INTEREST_PER_SHARE_DENORM = 1e18;
    uint constant APY_DENORM = 1e6;
    uint constant SECONDS_IN_ONE_DAY = 86400;
    
    ICerbyTokenMinterBurner cerbyToken = ICerbyTokenMinterBurner(
        0xdef1fac7Bf08f173D286BbBDcBeeADe695129840
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
   
    event BurnedAndAddedToStakersInflation(
        address fromAddr, 
        uint amountToBurn, 
        uint currentDay
    );
    
    constructor() 
    {
        settings.MINIMUM_DAYS_FOR_HIGH_PENALTY = 0;
        settings.CONTROLLED_APY = 4e5; // 40%
        settings.END_STAKE_FROM = 30;
        settings.END_STAKE_TO = 2*DAYS_IN_ONE_YEAR; // 5% per month penalty
        settings.MINIMUM_STAKE_DAYS = 1;
        settings.MAXIMUM_STAKE_DAYS = 100*DAYS_IN_ONE_YEAR;
        settings.LONGER_PAYS_BETTER_BONUS = 3e6; // 3e6/1e6 = 300% shares bonus max
        settings.SMALLER_PAYS_BETTER_BONUS = 25e4; // 25e4/1e6 = 25% shares bonus max        
        
        launchTimestamp = 1635604537; // 30 October 2021
        
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
            0
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
    
    modifier onlyRealUsers()
    {
        ICerbyBotDetection iCerbyBotDetection = ICerbyBotDetection(
            ICerbyTokenMinterBurner(cerbyToken).getUtilsContractAtPos(CERBY_BOT_DETECTION_CONTRACT_ID)
        );
        require(
            !iCerbyBotDetection.isBotAddress(msg.sender),
            "SS: Only real users allowed!"
        );
        _;
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

    modifier executeCron()
    {
        _;
    }
    
    function adminUpdateSettings(Settings calldata _settings)
        public
        onlyRole(ROLE_ADMIN)
    {
        settings = _settings;
        
        emit SettingsUpdated(_settings);
    }

    function adminBulkTransferOwnership(uint[] calldata stakeIds, address oldOwner, address newOwner)
        public
        onlyRole(ROLE_ADMIN)
    {
        updateAllSnapshots();

        for(uint i = 0; i<stakeIds.length; i++)
        {
            require(
                stakes[stakeIds[i]].owner != newOwner,
                "SS: New owner must be different from old owner"
            );
            require(
                stakes[stakeIds[i]].owner == oldOwner,
                "SS: Stake owner does not match"
            );            

            _transferOwnership(stakeIds[i], newOwner);
        }          
    }
    
    function adminBurnAndAddToStakersInflation(address fromAddr, uint amountToBurn)
        public
        onlyRole(ROLE_ADMIN)
    {
        updateAllSnapshots();
        
        cerbyToken.burnHumanAddress(fromAddr, amountToBurn);
        
        uint today = getCurrentDaySinceLaunch();
        dailySnapshots[today].inflationAmount += amountToBurn;
        
        emit BurnedAndAddedToStakersInflation(fromAddr, amountToBurn, today);
    }
    
    function bulkTransferOwnership(uint[] calldata stakeIds, address newOwner)
        public
    {
        for(uint i = 0; i<stakeIds.length; i++)
        {
            transferOwnership(stakeIds[i], newOwner);
        }
    }
    
    function transferOwnership(uint stakeId, address newOwner)
        public
        onlyRealUsers()
        onlyStakeOwners(stakeId)
        onlyExistingStake(stakeId)
        onlyActiveStake(stakeId)
    {
        require(
            stakes[stakeId].owner != newOwner,
            "SS: New owner must be different from old owner"
        );
        
        updateAllSnapshots();

        _transferOwnership(stakeId, newOwner);        
    }

    function _transferOwnership(uint stakeId, address newOwner)
        private
    {
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
                cerbyToken.totalSupply()
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
        onlyRealUsers()
        returns(uint stakeId)
    {
        require(
            _startStake.stakedAmount > 0,
            "SS: StakedAmount has to be larger than zero"
        );
        require(
            _startStake.stakedAmount <= cerbyToken.balanceOf(msg.sender),
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
        
        cerbyToken.transferCustom(msg.sender, address(this), _startStake.stakedAmount);
        
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
            endStake(stakeIds[i]);
        }
    }
    
    function endStake(
        uint stakeId
    )
        public
        onlyRealUsers()
        onlyStakeOwners(stakeId)
        onlyExistingStake(stakeId)
        onlyActiveStake(stakeId)
    {
        updateAllSnapshots();
        
        uint today = getCurrentDaySinceLaunch();
        stakes[stakeId].endDay = today;
        
        cerbyToken.transferCustom(address(this), msg.sender, stakes[stakeId].stakedAmount);
        
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
            cerbyToken.mintHumanAddress(msg.sender, interest);
        }
        
        uint penalty = getPenaltyByStake(stakes[stakeId], today, interest);
        if (penalty > 0) 
        {
            cerbyToken.burnHumanAddress(msg.sender, penalty);
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
            scrapeStake(stakeIds[i]);
        }
    }
    
    function scrapeStake(
        uint stakeId
    )
        public
        onlyRealUsers()
        onlyStakeOwners(stakeId)
        onlyExistingStake(stakeId)
        onlyActiveStake(stakeId)
    {
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
        
        endStake(stakeId);
        
        uint newLockedForXDays = oldLockedForXDays - stakes[stakeId].lockedForXDays;
        startStake(StartStake(stakes[stakeId].stakedAmount, newLockedForXDays));
    }
    
    function getTotalTokensStaked()
        public
        view
        returns(uint)
    {
        return ICerbyTokenMinterBurner(cerbyToken).balanceOf(address(this));
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
        endDay = minOfTwoUints(endDay, dailySnapshots.length);
        
        uint sharesCount = getSharesCountByStake(stake, givenDay);
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
        view
        returns (uint)
    {
        /*
        0 -- 0 days served => 0% principal back
        0 days -- 100% served --> 0-100% (principal+interest) back
        100% + 30 days --> 100% (principal+interest) back
        100% + 30 days -- 100% + 30 days + 2*365 days --> 100-10% (principal+interest) back
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
    
    function getCurrentDaySinceLaunch()
        public
        view
        returns (uint)
    {
        return 1 + block.timestamp / SECONDS_IN_ONE_DAY - launchTimestamp / SECONDS_IN_ONE_DAY;
    }
    
    function getCurrentCachedPerShareDay()
        public
        view
        returns (uint)
    {
        return getCurrentDaySinceLaunch() / CACHED_DAYS_INTEREST;
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
