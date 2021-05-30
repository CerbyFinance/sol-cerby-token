// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/INoBotsTech.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";


contract NoBotsTechV2 is AccessControlEnumerable {
    bytes32 public constant ROLE_DEX = keccak256("ROLE_DEX");
    bytes32 public constant ROLE_BOT = keccak256("ROLE_BOT");
    bytes32 public constant ROLE_WHITELISTED_CONTRACT = keccak256("ROLE_WHITELISTED_CONTRACT");
    bytes32 public constant ROLE_TEAM_BENEFICIARY = keccak256("ROLE_TEAM_BENEFICIARY");
    
    uint constant BALANCE_MULTIPLIER_DENORM = 1e18;
    uint public cachedMultiplier = BALANCE_MULTIPLIER_DENORM;
    
    
    uint public batchBurnAndReward;
    uint public lastCachedTimestamp = block.timestamp;
    uint public secondsBetweenRecacheUpdates = 0;
    
    uint public botTaxPercent = 99e4; // 99.0%
    uint public firstMinutesTaxPercent = 99e4; // 99.0%
    uint public howManyFirstMinutesIncreasedTax = 60 minutes;
    uint constant TAX_PERCENT_DENORM = 1e6;
    
    uint public cycleOneStartTaxPercent = 50e4; // 50.0%
    uint public cycleOneEnds = 120 days;
    
    uint public cycleTwoStartTaxPercent = 25e4; // 25.0%
    uint public cycleTwoEnds = 240 days;
    
    uint public cycleThreeStartTaxPercent = 10e4; // 10.0%
    uint public cycleThreeEnds = 360 days;
    uint public cycleThreeEndTaxPercent = 0; // 0%
    
    address constant BURN_ADDRESS = address(0x0);
    
    uint public rewardsBalance;
    uint public realTotalSupply;
    
    mapping(address => uint) buyTimestampStorage;
    
    struct CurrectCycle {
        uint currentCycleTax;
        uint howMuchTimeLeftTillEndOfCycleThree;
    }
    
    struct RoleAccess {
        bytes32 role;
        address addr;
    }
    
    event MultiplierUpdated(uint newMultiplier);
    event BotTransactionDetected(address from, address to, uint transferAmount, uint taxedAmount);
    
    constructor() {
        _setupRole(ROLE_ADMIN, _msgSender());
        
        emit MultiplierUpdated(cachedMultiplier);
    }
    
    function grantRolesBulk(RoleAccess[] calldata roles)
        external
        onlyRole(ROLE_ADMIN)
    {
        for(uint i = 0; i<roles.length; i++)
        {
            _setupRole(roles[i].role, roles[i].addr);
        }
    }
    
    function updateSecondsBetweenReCacheUpdates(uint _secondsBetweenRecacheUpdates)
        external
        onlyRole(ROLE_ADMIN)
    {
        secondsBetweenRecacheUpdates = _secondsBetweenRecacheUpdates;
    }
    
    function isNotContract(address account) 
        private
        view
        returns (bool)
    {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size == 0;
    }
    
    function isContract(address account) 
        private
        view
        returns (bool)
    {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
    
    function getTotalSupply()
        external
        onlyRole(ROLE_ADMIN)
        view
        returns (uint)
    {
        return realTotalSupply + rewardsBalance;
    }
    
    function getRewardsBalance()
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint)
    {
        return rewardsBalance;
    }
    
    function delayedUpdateCacheMultiplier()
        private
    {   
        if (block.timestamp > lastCachedTimestamp + secondsBetweenRecacheUpdates)
        {
            forcedUpdateCacheMultiplier();
        }
    }
    
    function forcedUpdateCacheMultiplier()
        private
    {   
        lastCachedTimestamp = block.timestamp;
    
        realTotalSupply -= batchBurnAndReward;
        rewardsBalance += batchBurnAndReward/2; // Half of burned amount goes to rewards to all DEFT holders
        batchBurnAndReward = 0;
        
        cachedMultiplier = BALANCE_MULTIPLIER_DENORM + 
            (BALANCE_MULTIPLIER_DENORM * rewardsBalance) / realTotalSupply;
            
        emit MultiplierUpdated(cachedMultiplier);
    }
    
    function publicForcedUpdateCacheMultiplier()
        public
    {   
        forcedUpdateCacheMultiplier();
    }
    
    function chargeCustomTax(uint taxAmount, uint accountBalance)
        external
        onlyRole(ROLE_ADMIN)
        returns(uint)
    {
        uint realTaxAmount = 
            (taxAmount * BALANCE_MULTIPLIER_DENORM) / cachedMultiplier;
        
        accountBalance -= realTaxAmount;
        batchBurnAndReward += realTaxAmount;
        
        delayedUpdateCacheMultiplier();
        
        return accountBalance;
    }
 
    function prepareTaxAmounts(
        TaxAmountsInput calldata taxAmountsInput
    ) 
        external
        onlyRole(ROLE_ADMIN)
        returns(TaxAmountsOutput memory taxAmountsOutput)
    {
        uint realTransferAmount = 
            (taxAmountsInput.transferAmount * BALANCE_MULTIPLIER_DENORM) / cachedMultiplier;
        
        require(
            realTransferAmount > 0,
            "NBT: !amount"
        );
        
        uint timePassedSinceLastBuy = block.timestamp > buyTimestampStorage[taxAmountsInput.sender]?
                                        block.timestamp - buyTimestampStorage[taxAmountsInput.sender]: 0;
                                        
        bool isBuy = hasRole(ROLE_DEX, taxAmountsInput.sender);
        bool isSell = hasRole(ROLE_DEX, taxAmountsInput.recipient);
        bool isEarlySell = isSell && (timePassedSinceLastBuy < howManyFirstMinutesIncreasedTax);
        
        bool isSenderHuman =    
                !isEarlySell &&
                !hasRole(ROLE_BOT, taxAmountsInput.sender) &&
                    (
                        isNotContract(taxAmountsInput.sender) || 
                        hasRole(ROLE_DEX, taxAmountsInput.sender) || 
                        hasRole(ROLE_WHITELISTED_CONTRACT, taxAmountsInput.sender)
                    );
        
        uint burnAndRewardRealAmount;
        if (isSenderHuman)
        {
            if (isSell)
            {
                // human
                // buys - 0% tax
                // sells - cycle tax
                // transfers - 0% tax
                
                uint cycleTaxPercent = calculateCurrentCycleTax(timePassedSinceLastBuy);
                burnAndRewardRealAmount = (realTransferAmount * cycleTaxPercent) / TAX_PERCENT_DENORM;
            }
        } else
        {
            if (!isBuy)
            {
                // bot
                // buys - 0% tax
                // sells - 99% tax
                // transfers - 99% tax
                
                burnAndRewardRealAmount = (realTransferAmount * botTaxPercent) / TAX_PERCENT_DENORM;
                
                uint botTaxedAmount = (taxAmountsInput.transferAmount * botTaxPercent) / TAX_PERCENT_DENORM;
                emit BotTransactionDetected(
                    taxAmountsInput.sender, 
                    taxAmountsInput.recipient, 
                    taxAmountsInput.transferAmount,
                    botTaxedAmount
                );
            }
        }
        
        
        if (!isSell)
        { // isBuy or isTransfer: Updating cycle based on realTransferAmount
        
            uint howManyDaysLeft = 
                    cycleThreeEnds > buyTimestampStorage[taxAmountsInput.recipient]? 
                        cycleThreeEnds - buyTimestampStorage[taxAmountsInput.recipient]:
                        0;
        
            uint newHowManyDaysLeft = 
                (taxAmountsInput.recipientRealBalance * howManyDaysLeft + realTransferAmount * cycleThreeEnds) /
                    (taxAmountsInput.recipientRealBalance + realTransferAmount);
            
            buyTimestampStorage[taxAmountsInput.recipient] = cycleThreeEnds - newHowManyDaysLeft;
        }
        
        uint recipientGetsRealAmount = realTransferAmount - burnAndRewardRealAmount;
        taxAmountsOutput.senderRealBalance = taxAmountsInput.senderRealBalance - realTransferAmount;
        taxAmountsOutput.recipientRealBalance = taxAmountsInput.recipientRealBalance + recipientGetsRealAmount;
        batchBurnAndReward += burnAndRewardRealAmount;       
        
        taxAmountsOutput.burnAndRewardAmount = 
            (burnAndRewardRealAmount * cachedMultiplier) / BALANCE_MULTIPLIER_DENORM; // Actual amount we burned and have to show in event
        taxAmountsOutput.recipientGetsAmount = 
            taxAmountsInput.transferAmount - taxAmountsOutput.burnAndRewardAmount; // Actual amount recipient got and have to show in event
        
        
        
        delayedUpdateCacheMultiplier();
        
        return taxAmountsOutput;
    }
    
    function calculateCurrentCycleTax(uint timePassedSinceLastBuy)
        private
        view
        returns (uint)
    {
        if (timePassedSinceLastBuy > cycleThreeEnds)
        {
            return cycleThreeEndTaxPercent;
        } else if (timePassedSinceLastBuy > cycleTwoEnds)
        {
            return  (cycleThreeStartTaxPercent * (cycleThreeEnds - timePassedSinceLastBuy)) /
                        (cycleThreeEnds - cycleTwoEnds);
        } else if (timePassedSinceLastBuy > cycleOneEnds)
        {
            return  cycleTwoStartTaxPercent -
                    ((cycleTwoStartTaxPercent - cycleThreeStartTaxPercent) * (timePassedSinceLastBuy - cycleOneEnds)) /
                        (cycleTwoEnds - cycleOneEnds);
        } else // timePassedSinceLastBuy <= cycleOneEnds
        {
            return  cycleOneStartTaxPercent -
                    ((cycleOneStartTaxPercent - cycleTwoStartTaxPercent) * timePassedSinceLastBuy) / cycleOneEnds;
        }
    }
    
    function getWalletCurrentCycle(address addr)
        external
        returns (CurrectCycle memory currentCycle)
    {
        uint howMuchTimePassedSinceBuy = 
            block.timestamp > buyTimestampStorage[addr]?
                block.timestamp - buyTimestampStorage[addr]:
                0;
        
        currentCycle.currentCycleTax = calculateCurrentCycleTax(howMuchTimePassedSinceBuy);
        currentCycle.howMuchTimeLeftTillEndOfCycleThree = 
            howMuchTimePassedSinceBuy < cycleThreeEnds?
                cycleThreeEnds - howMuchTimePassedSinceBuy:
                0;
        return currentCycle;
    }
    
    function prepareHumanAddressMintOrBurnRewardsAmounts(bool isMint, address account, uint desiredAmountToMintOrBurn)
        external
        onlyRole(ROLE_ADMIN)
        returns (uint)
    {
        uint realAmountToMintOrBurn = (BALANCE_MULTIPLIER_DENORM * desiredAmountToMintOrBurn) / cachedMultiplier;
        uint rewardToMintOrBurn = desiredAmountToMintOrBurn - realAmountToMintOrBurn;
        if (isMint) 
        {
            rewardsBalance += rewardToMintOrBurn;
            realTotalSupply += realAmountToMintOrBurn;
        } else
        {
            rewardsBalance -= rewardToMintOrBurn;
            realTotalSupply -= realAmountToMintOrBurn;
        }
        
        forcedUpdateCacheMultiplier();
        
        return realAmountToMintOrBurn;
    }
    
    function getBalance(address account, uint accountBalance)
        external
        onlyRole(ROLE_ADMIN)
        view
        returns(uint)
    {
        return (accountBalance * cachedMultiplier) / BALANCE_MULTIPLIER_DENORM;
    }
    
    function getRealBalance(address account, uint accountBalance)
        external
        onlyRole(ROLE_ADMIN)
        view
        returns(uint)
    {
        return (accountBalance * BALANCE_MULTIPLIER_DENORM) / cachedMultiplier;
    }
}