// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.7;

import "./interfaces/IDefiFactoryToken.sol";

struct DailySnapshot {
    uint inflationAmount;
    uint totalSupply;
    uint totalShares;
    uint sharePrice;
}

struct Stake {
    uint stakedAmount;
    uint startDay;
    uint lockedForXDays;
    uint endDay;
}

contract StakingSystem {
    mapping(uint => DailySnapshot) snapshots;
    mapping(address => Stake[]) stakers;
    
    uint constant SHARE_PRICE_DENORM = 1e6;
    uint currentSharePrice = SHARE_PRICE_DENORM;
    
    IDefiFactoryToken mainToken = IDefiFactoryToken(0x7A7492a8e888Ca3fe8e31cB2E34872FE0CE5309f);
    
    constructor() {}
    
    function startStake(
        uint stakedAmount,
        uint lockedForXDays
    )
        public
    {
        require(
            mainToken.balanceOf(msg.sender) >= stakedAmount,
            "SS: StakedAmount exceeds balance"
        );
        
        mainToken.burnHumanAddress(msg.sender, stakedAmount);
        
        uint startDay = getCurrentDay();
        stakers[msg.sender].push(
            Stake(
                stakedAmount,
                startDay,
                lockedForXDays,
                0
            )
        );
        
        uint sharesCount = getSharesCount(msg.sender, stakers[msg.sender].length, startDay);
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
        
        stakers[msg.sender][stakePosition].endDay = getCurrentDay();
    }
    
    function getSharesCount(address stakerAddress, uint stakePosition, uint givenDay)
        public
        view
        returns (uint)
    {
        Stake memory stake = stakers[stakerAddress][stakePosition];
        DailySnapshot memory startDaySnapshot = snapshots[stake.startDay];
        
        uint numberOfDaysServed = givenDay == 0? stake.lockedForXDays: givenDay - stake.startDay;
        
        /*
            20yr - 5x
            10yr - 2.5x
            1yr - 0.25x
            1d - 0.0006849x
        */
        uint sharesCount = 
            (5 * numberOfDaysServed * stake.stakedAmount * SHARE_PRICE_DENORM) / (20 * 365 * startDaySnapshot.sharePrice);
        return sharesCount;
    }
    
    function getCurrentDay()
        public
        pure
        returns (uint)
    {
        return 1;
    }
    
}