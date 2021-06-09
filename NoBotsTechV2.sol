// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/INoBotsTech.sol";
import "./interfaces/IWeth.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IDeftStorageContract.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";



contract NoBotsTechV2 is AccessControlEnumerable {
    bytes32 public constant ROLE_DEX = keccak256("ROLE_DEX");
    bytes32 public constant ROLE_TEAM_MARKETING = keccak256("ROLE_TEAM_MARKETING");
    bytes32 public constant ROLE_TEAM_DEVELOPING = keccak256("ROLE_TEAM_DEVELOPING");
    
    uint public teamMarketingSplit = 1667e2;
    uint public teamDevelopingSplit = TAX_PERCENT_DENORM - teamMarketingSplit;
    
    uint constant UNISWAP_V2_PAIR_ADDRESS_ID = 3;
    uint constant NATIVE_TOKEN_ADDRESS_ID = 4;
    
    uint constant BALANCE_MULTIPLIER_DENORM = 1e18;
    uint public cachedMultiplier = BALANCE_MULTIPLIER_DENORM;
    
    
    uint public batchBurnAndReward;
    uint public lastCachedTimestamp = block.timestamp;
    uint public secondsBetweenRecacheUpdates = 0;
    
    
    address public defiFactoryTokenAddress;
    address public deftStorageAddress;
    
    uint public teamPercentOfTax = 5e4;
    
    uint public botTaxPercent = 99e4; // 99.0%
    uint public howManyFirstMinutesIncreasedTax = 0 minutes;
    uint constant TAX_PERCENT_DENORM = 1e6;
    
    uint public cycleOneStartTaxPercent = 15e4; // 15.0%
    uint public cycleOneEnds = 120 days;
    
    uint public cycleTwoStartTaxPercent = 10e4; // 10.0%
    uint public cycleTwoEnds = 240 days;
    
    uint public cycleThreeStartTaxPercent = 7e4; // 7.0%
    uint public cycleThreeEnds = 360 days;
    uint public cycleThreeEndTaxPercent = 5e4; // 5.0%
    
    uint public buyLimitAmount;
    uint public buyLimitPercent = 1e4; // 1%
    
    
    address constant BURN_ADDRESS = address(0x0);
    
    uint public rewardsBalance;
    uint public realTotalSupply;
    uint public earlyInvestorTimestamp;
    
    uint public teamRewards;
    
    mapping(address => uint) public buyTimestampStorage;
    
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
    event TeamTaxRewardsSent(address to, uint transferAmount);
    event BuyLimitAmountUpdated(uint newBuyLimitAmount);
    event TeamTaxRewardsUpdated(address teamAddress, uint teamRewards);
    event WalletBuyTimestampUpdated(address wallet, uint buyTimestamp);
    
    constructor() {
        _setupRole(ROLE_ADMIN, _msgSender());
        _setupRole(ROLE_TEAM_MARKETING, _msgSender());
        _setupRole(ROLE_TEAM_DEVELOPING, _msgSender());
        
        earlyInvestorTimestamp = block.timestamp - 30 days;
        
        buyTimestampStorage[0x539FaA851D86781009EC30dF437D794bCd090c8F] = block.timestamp - 35 days;
        buyTimestampStorage[0xAAa96EB7c2b9C22144f8B742a5Afdabab3b6781f] = block.timestamp - 140 days;
        buyTimestampStorage[0xBbB6AE3051C5b486836a32193D8D191572C7cC1D] = block.timestamp - 333 days;
        buyTimestampStorage[0x987De8C41CB9e166E51a4913e560c08c2760EfE5] = block.timestamp - 600 days;
        
        realTotalSupply = 1;
        rewardsBalance = 0;
        
        cachedMultiplier = BALANCE_MULTIPLIER_DENORM + 
                (BALANCE_MULTIPLIER_DENORM * rewardsBalance) / realTotalSupply;
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
    
    function updateTeamSplit(uint _teamMarketingSplit, uint _teamDevelopingSplit)
        external
        onlyRole(ROLE_ADMIN)
    {
        teamMarketingSplit = _teamMarketingSplit;
        teamDevelopingSplit = _teamDevelopingSplit;
    }
    
    function updateBuyLimitPercent(uint _buyLimitPercent)
        external
        onlyRole(ROLE_ADMIN)
    {
        buyLimitPercent = _buyLimitPercent;
    }
    
    function updateTeamPercentOfTax(uint _teamPercentOfTax)
        external
        onlyRole(ROLE_ADMIN)
    {
        teamPercentOfTax = _teamPercentOfTax;
    }
    
    function updateDefiFactoryTokenAddress(address _defiFactoryTokenAddress)
        external
        onlyRole(ROLE_ADMIN)
    {
        defiFactoryTokenAddress = _defiFactoryTokenAddress;
    }
    
    function updateBotStorageAddress(address _deftStorageAddress)
        external
        onlyRole(ROLE_ADMIN)
    {
        deftStorageAddress = _deftStorageAddress;
    }
    
    function updateSecondsBetweenUpdates(uint _secondsBetweenRecacheUpdates)
        external
        onlyRole(ROLE_ADMIN)
    {
        secondsBetweenRecacheUpdates = _secondsBetweenRecacheUpdates;
    }
    
    function updateBotTaxSettings(uint _botTaxPercent, uint _howManyFirstMinutesIncreasedTax)
        external
        onlyRole(ROLE_ADMIN)
    {
        botTaxPercent = _botTaxPercent;
        howManyFirstMinutesIncreasedTax = _howManyFirstMinutesIncreasedTax;
    }
    
    function updateCycleOneSettings(uint _cycleOneStartTaxPercent, uint _cycleOneEnds)
        external
        onlyRole(ROLE_ADMIN)
    {
        cycleOneStartTaxPercent = _cycleOneStartTaxPercent;
        cycleOneEnds = _cycleOneEnds;
    }
    
    function updateCycleTwoSettings(uint _cycleTwoStartTaxPercent, uint _cycleTwoEnds)
        external
        onlyRole(ROLE_ADMIN)
    {
        cycleTwoStartTaxPercent = _cycleTwoStartTaxPercent;
        cycleTwoEnds = _cycleTwoEnds;
    }
    
    function updateCycleTwoSettings(uint _cycleThreeStartTaxPercent, uint _cycleThreeEnds, uint _cycleThreeEndTaxPercent)
        external
        onlyRole(ROLE_ADMIN)
    {
        cycleThreeStartTaxPercent = _cycleThreeStartTaxPercent;
        cycleThreeEnds = _cycleThreeEnds;
        cycleThreeEndTaxPercent = _cycleThreeEndTaxPercent;
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
    
    function delayedUpdateCache()
        private
    {   
        if (block.timestamp > lastCachedTimestamp + secondsBetweenRecacheUpdates)
        {
            forcedUpdateCache();
        }
    }
    
    function forcedUpdateCache()
        private
    {   
        lastCachedTimestamp = block.timestamp;
    
        if (batchBurnAndReward > 0)
        {
            uint _teamRewards = (batchBurnAndReward * teamPercentOfTax) / TAX_PERCENT_DENORM;
            uint distributeRewards = batchBurnAndReward - _teamRewards;
            rewardsBalance += distributeRewards; // 95% of amount goes to rewards to DEFT holders
            realTotalSupply -= batchBurnAndReward;
            batchBurnAndReward = 0;
            
            uint oldRewardsBalance = rewardsBalance;
            
            if (_teamRewards > 0)
            {
                address teamMarketingAddress = getRoleMember(ROLE_TEAM_MARKETING, 0);
                uint teamMarketingAmount = 
                    (_teamRewards * cachedMultiplier * teamMarketingSplit) / (BALANCE_MULTIPLIER_DENORM * TAX_PERCENT_DENORM);
                IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryTokenAddress);
                iDefiFactoryToken.mintHumanAddress(
                    teamMarketingAddress, 
                    teamMarketingAmount
                );
                
                address teamDevelopingAddress = getRoleMember(ROLE_TEAM_DEVELOPING, 0);
                uint teamDevelopingAmount = 
                    (_teamRewards * cachedMultiplier * teamDevelopingSplit) / (BALANCE_MULTIPLIER_DENORM * TAX_PERCENT_DENORM);
                iDefiFactoryToken.mintHumanAddress(
                    teamMarketingAddress, 
                    teamDevelopingAmount
                );
                
                rewardsBalance = oldRewardsBalance;
                
                emit TeamTaxRewardsUpdated(teamDevelopingAddress, teamDevelopingAmount);
                emit TeamTaxRewardsUpdated(teamMarketingAddress, teamMarketingAmount);
            }
            
            cachedMultiplier = BALANCE_MULTIPLIER_DENORM + 
                (BALANCE_MULTIPLIER_DENORM * rewardsBalance) / realTotalSupply;
            
            emit MultiplierUpdated(cachedMultiplier);
        }
        
        if (buyLimitPercent < TAX_PERCENT_DENORM)
        {
            address pairAddress = IDefiFactoryToken(defiFactoryTokenAddress).
                    getUtilsContractAtPos(UNISWAP_V2_PAIR_ADDRESS_ID);
            uint deftBalance = IWeth(defiFactoryTokenAddress).balanceOf(pairAddress);
            buyLimitAmount = (deftBalance * buyLimitPercent) / TAX_PERCENT_DENORM;
            
            emit BuyLimitAmountUpdated(buyLimitAmount);
        }
    }
    
    function publicForcedUpdateCacheMultiplier()
        public
    {   
        if (block.timestamp > lastCachedTimestamp)
        {
            forcedUpdateCache();
        }
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
        
        delayedUpdateCache();
        
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
        
        IsHumanInfo memory isHumanInfo = IDeftStorageContract(deftStorageAddress).
            isHumanTransaction(defiFactoryTokenAddress, taxAmountsInput.sender, taxAmountsInput.recipient);
        
        require (
            !isHumanInfo.isBuy ||
            isHumanInfo.isBuy &&
            buyLimitPercent < TAX_PERCENT_DENORM &&
            taxAmountsInput.transferAmount < buyLimitAmount,
            "NBT: !buy_limit"
        );
        
        uint timePassedSinceLastBuy = block.timestamp > buyTimestampStorage[taxAmountsInput.sender]?
                                        block.timestamp - buyTimestampStorage[taxAmountsInput.sender]: 0;
        bool isSenderHuman =    
                !(isHumanInfo.isSell && (timePassedSinceLastBuy < howManyFirstMinutesIncreasedTax)) && // !isEarlySell
                isHumanInfo.isHumanTransaction;
        
        uint burnAndRewardRealAmount;
        if (isSenderHuman)
        {
            if (isHumanInfo.isSell)
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
            if (!isHumanInfo.isBuy)
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
        
        
        if (!isHumanInfo.isSell)
        { // isBuy or isTransfer: Updating cycle based on realTransferAmount
            uint buyTimestampAddr = getUpdatedBuyTimestampOfEarlyInvestor(taxAmountsInput.recipient, taxAmountsInput.recipientRealBalance);
            buyTimestampAddr = getNewBuyTimestamp(buyTimestampAddr, taxAmountsInput.recipientRealBalance, realTransferAmount);
            
            buyTimestampStorage[taxAmountsInput.recipient] = buyTimestampAddr;
            emit WalletBuyTimestampUpdated(taxAmountsInput.recipient, buyTimestampAddr);
        }
        
        
        uint recipientGetsRealAmount = realTransferAmount - burnAndRewardRealAmount;
        taxAmountsOutput.senderRealBalance = taxAmountsInput.senderRealBalance - realTransferAmount;
        taxAmountsOutput.recipientRealBalance = taxAmountsInput.recipientRealBalance + recipientGetsRealAmount;
        batchBurnAndReward += burnAndRewardRealAmount;       
        
        taxAmountsOutput.burnAndRewardAmount = 
            (burnAndRewardRealAmount * cachedMultiplier) / BALANCE_MULTIPLIER_DENORM; // Actual amount we burned and have to show in event
        taxAmountsOutput.recipientGetsAmount = 
            taxAmountsInput.transferAmount - taxAmountsOutput.burnAndRewardAmount; // Actual amount recipient got and have to show in event
        
        delayedUpdateCache();
        
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
        } else if (timePassedSinceLastBuy > howManyFirstMinutesIncreasedTax)
        {
            return  cycleOneStartTaxPercent -
                    ((cycleOneStartTaxPercent - cycleTwoStartTaxPercent) * timePassedSinceLastBuy) / cycleOneEnds;
        } else // timePassedSinceLastBuy < howManyFirstMinutesIncreasedTax
        {
            return botTaxPercent;
        }
    }
    
    function getWalletCurrentCycle(address addr)
        external
        view
        returns (CurrectCycle memory currentCycle)
    {
        
        if (IDeftStorageContract(deftStorageAddress).isBotAddress(addr))
        {
            currentCycle.currentCycleTax = botTaxPercent;
            currentCycle.howMuchTimeLeftTillEndOfCycleThree = cycleThreeEnds;
        } else
        {
            uint accountBalance = IDefiFactoryToken(defiFactoryTokenAddress).balanceOf(addr);
            uint buyTimestampAddr = getUpdatedBuyTimestampOfEarlyInvestor(addr, accountBalance);
            uint howMuchTimePassedSinceBuy = 
                block.timestamp > buyTimestampAddr?
                    block.timestamp - buyTimestampAddr:
                    0;
            
            currentCycle.currentCycleTax = calculateCurrentCycleTax(howMuchTimePassedSinceBuy);
            currentCycle.howMuchTimeLeftTillEndOfCycleThree = 
                howMuchTimePassedSinceBuy < cycleThreeEnds?
                    cycleThreeEnds - howMuchTimePassedSinceBuy:
                    0;
        }
        return currentCycle;
    }
    
    function getUpdatedBuyTimestampOfEarlyInvestor(address addr, uint accountBalance)
        private
        view
        returns (uint)
    {
        uint buyTimestampAddr = block.timestamp;
        if (buyTimestampStorage[addr] == 0 && accountBalance != 0)
        {
            buyTimestampAddr = earlyInvestorTimestamp;
        } else if (buyTimestampStorage[addr] != 0)
        {
            buyTimestampAddr = buyTimestampStorage[addr];
        }
        
        return buyTimestampAddr;
    }
    
    function getNewBuyTimestamp(uint currentTimestamp, uint accountBalance, uint receivedAmount)
        private
        view
        returns(uint)
    {
        uint timestampCycleThreeEnds = cycleThreeEnds + currentTimestamp;
        uint howManyDaysLeft = 
                    timestampCycleThreeEnds > block.timestamp? 
                        timestampCycleThreeEnds - block.timestamp:
                        0;
        
        //weighted average between howManyDaysLeft and 365
        uint weightedAverageHowManyDaysLeft = 
            (accountBalance * howManyDaysLeft + receivedAmount * cycleThreeEnds) /
                (accountBalance + receivedAmount);
        return currentTimestamp - weightedAverageHowManyDaysLeft + howManyDaysLeft;
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
            
            uint accountBalance = IDefiFactoryToken(defiFactoryTokenAddress).balanceOf(account);
            uint buyTimestampAddr = getUpdatedBuyTimestampOfEarlyInvestor(account, accountBalance);
            buyTimestampAddr = getNewBuyTimestamp(buyTimestampAddr, accountBalance, desiredAmountToMintOrBurn);
            
            buyTimestampStorage[account] = buyTimestampAddr;
            emit WalletBuyTimestampUpdated(account, buyTimestampAddr);
        } else
        {
            rewardsBalance -= rewardToMintOrBurn;
            realTotalSupply -= realAmountToMintOrBurn;
        }
        
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