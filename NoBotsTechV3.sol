// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.7;

import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/INoBotsTech.sol";
import "./interfaces/IWeth.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IDeftStorageContract.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";



contract NoBotsTechV3 is AccessControlEnumerable {
    
    uint constant DEFT_STORAGE_CONTRACT_ID = 3;
    uint constant UNISWAP_V2_PAIR_ADDRESS_ID = 4;
    
    
    uint public lastCachedTimestamp = block.timestamp;
    uint public lastPaidFeeTimestamp = block.timestamp;
    
    
    
    address public defiFactoryTokenAddress = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840;
    
    uint public botTaxPercent = 999e3; // 99.9%
    uint constant TAX_PERCENT_DENORM = 1e6;
    
    /* DEFT Taxes: */
    uint public cycleOneStartTaxPercent = 0; // 15.0%
    uint public cycleOneEnds = 0 days;
    uint public cycleTwoStartTaxPercent = 0; // 8.0%
    uint public cycleTwoEnds = 0 days;
    uint public cycleThreeStartTaxPercent = 0; // 3.0%
    uint public cycleThreeEnds = 0 days;
    uint public cycleThreeEndTaxPercent = 0; // 0.0% 
    
    /* Lambo Taxes */
    /*
    uint public cycleOneStartTaxPercent = 30e4; // 30.0%
    uint public cycleOneEnds = 0 days;
    uint public cycleTwoStartTaxPercent = 30e4; // 30.0%
    uint public cycleTwoEnds = 0 days;
    uint public cycleThreeStartTaxPercent = 30e4; // 30.0%
    uint public cycleThreeEnds = 7 days;
    uint public cycleThreeEndTaxPercent = 5e4; // 5.0%
    */
    
    uint constant ETH_MAINNET_CHAIN_ID = 1;
    uint constant ETH_ROPSTEN_CHAIN_ID = 3;
    uint constant ETH_KOVAN_CHAIN_ID = 42;
    uint constant BSC_MAINNET_CHAIN_ID = 56;
    uint constant BSC_TESTNET_CHAIN_ID = 97;
    
    address constant BURN_ADDRESS = address(0x0);
    
    uint public realTotalSupply;
    
    
    struct CurrectCycle {
        uint currentCycleTax;
        uint howMuchTimeLeftTillEndOfCycleThree;
    }
    
    event BotTransactionDetected(address from, address to, uint transferAmount, uint taxedAmount);
    
    constructor() {
        _setupRole(ROLE_ADMIN, _msgSender());
        _setupRole(ROLE_ADMIN, defiFactoryTokenAddress);
    }
    
    function updateTotalSupply(uint _realTotalSupply)
        external
        onlyRole(ROLE_ADMIN)
    {
        realTotalSupply = _realTotalSupply;
    }
    
    function updateDefiFactoryTokenAddress(address _defiFactoryTokenAddress)
        external
        onlyRole(ROLE_ADMIN)
    {
        defiFactoryTokenAddress = _defiFactoryTokenAddress;
    }
    
    function updateBotTaxSettings(uint _botTaxPercent)
        external
        onlyRole(ROLE_ADMIN)
    {
        botTaxPercent = _botTaxPercent;
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
    
    function updateCycleThreeSettings(uint _cycleThreeStartTaxPercent, uint _cycleThreeEnds, uint _cycleThreeEndTaxPercent)
        external
        onlyRole(ROLE_ADMIN)
    {
        cycleThreeStartTaxPercent = _cycleThreeStartTaxPercent;
        cycleThreeEnds = _cycleThreeEnds;
        cycleThreeEndTaxPercent = _cycleThreeEndTaxPercent;
    }
    
    function getTotalSupply()
        external
        onlyRole(ROLE_ADMIN)
        view
        returns (uint)
    {
        return realTotalSupply;
    }
    
    function publicForcedUpdateCacheMultiplier()
        public
    {   
        // Do nothing, for compability
    }
 
    function prepareTaxAmounts(
        TaxAmountsInput calldata taxAmountsInput
    ) 
        external
        onlyRole(ROLE_ADMIN)
        returns(TaxAmountsOutput memory taxAmountsOutput)
    {
        require(
            taxAmountsInput.transferAmount > 0,
            "NBT: !amount"
        );
        
        IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
                IDefiFactoryToken(defiFactoryTokenAddress).getUtilsContractAtPos(DEFT_STORAGE_CONTRACT_ID)
            );
        IsHumanInfo memory isHumanInfo = iDeftStorageContract.isHumanTransaction(defiFactoryTokenAddress, taxAmountsInput.sender, taxAmountsInput.recipient);
        
        
        uint burnAndRewardRealAmount;
        if (isHumanInfo.isHumanTransaction)
        {
            // human on main pair
            // buys - 0% tax
            // sells - cycle tax
            // transfers - 0% tax
            
            if (
                    isHumanInfo.isSell
                )
            {
                uint buyTimestampSender = 
                    getUpdatedBuyTimestampOfEarlyInvestor(taxAmountsInput.sender, taxAmountsInput.senderRealBalance);
                uint timePassedSinceLastBuy = 
                    block.timestamp > buyTimestampSender? block.timestamp - buyTimestampSender: 0;
                uint cycleTaxPercent = calculateCurrentCycleTax(timePassedSinceLastBuy);
                burnAndRewardRealAmount = (taxAmountsInput.transferAmount * cycleTaxPercent) / TAX_PERCENT_DENORM;
            }
        } else
        {
            burnAndRewardRealAmount = (taxAmountsInput.transferAmount * botTaxPercent) / TAX_PERCENT_DENORM;
            
            uint botTaxedAmount = (taxAmountsInput.transferAmount * botTaxPercent) / TAX_PERCENT_DENORM;
            emit BotTransactionDetected(
                taxAmountsInput.sender, 
                taxAmountsInput.recipient, 
                taxAmountsInput.transferAmount,
                botTaxedAmount
            );
        }
        
        if (!isHumanInfo.isSell)
        { // isBuy or isTransfer: Updating cycle based on realTransferAmount
            uint newBuyTimestamp = getUpdatedBuyTimestampOfEarlyInvestor(taxAmountsInput.recipient, taxAmountsInput.recipientRealBalance);
            newBuyTimestamp = getNewBuyTimestamp(newBuyTimestamp, taxAmountsInput.recipientRealBalance, taxAmountsInput.transferAmount);
            
            iDeftStorageContract.updateBuyTimestamp(defiFactoryTokenAddress, taxAmountsInput.recipient, newBuyTimestamp);
        }
        
        uint recipientGetsRealAmount = taxAmountsInput.transferAmount - burnAndRewardRealAmount;
        taxAmountsOutput.senderRealBalance = taxAmountsInput.senderRealBalance - taxAmountsInput.transferAmount;
        taxAmountsOutput.recipientRealBalance = taxAmountsInput.recipientRealBalance + recipientGetsRealAmount;
        realTotalSupply -= burnAndRewardRealAmount;       
        
        taxAmountsOutput.burnAndRewardAmount = burnAndRewardRealAmount; // Actual amount we burned and have to show in event
        taxAmountsOutput.recipientGetsAmount = 
            taxAmountsInput.transferAmount - burnAndRewardRealAmount; // Actual amount recipient got and have to show in event
        
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
        } else if (timePassedSinceLastBuy > 0)
        {
            return  cycleOneStartTaxPercent -
                    ((cycleOneStartTaxPercent - cycleTwoStartTaxPercent) * timePassedSinceLastBuy) / cycleOneEnds;
        } else
        {
            return botTaxPercent;
        }
    }
    
    function getWalletCurrentCycle(address addr)
        external
        view
        returns (CurrectCycle memory currentCycle)
    {
        
        if  (
                IDeftStorageContract(
                    IDefiFactoryToken(defiFactoryTokenAddress).getUtilsContractAtPos(DEFT_STORAGE_CONTRACT_ID)
                ).isBotAddress(addr)
            )
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
        uint newBuyTimestamp = block.timestamp;
        
        IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
                IDefiFactoryToken(defiFactoryTokenAddress).getUtilsContractAtPos(DEFT_STORAGE_CONTRACT_ID)
            );
            
        uint buyTimeStampAddr = iDeftStorageContract.getBuyTimestamp(defiFactoryTokenAddress, addr);
        if (buyTimeStampAddr != 0)
        {
            newBuyTimestamp = buyTimeStampAddr;
        } else if (accountBalance > 0)
        {
            newBuyTimestamp = block.timestamp; // earlyInvestorTimestamp
        }
        
        return newBuyTimestamp;
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
        return currentTimestamp + weightedAverageHowManyDaysLeft - howManyDaysLeft;
    }
    
    function prepareHumanAddressMintOrBurnRewardsAmounts(bool isMint, address account, uint desiredAmountToMintOrBurn)
        external
        onlyRole(ROLE_ADMIN)
        returns (uint)
    {
        if (isMint) 
        {
            realTotalSupply += desiredAmountToMintOrBurn;
            
            uint accountBalance = IDefiFactoryToken(defiFactoryTokenAddress).balanceOf(account);
            uint newBuyTimestampAccount = getUpdatedBuyTimestampOfEarlyInvestor(account, accountBalance);
            newBuyTimestampAccount = getNewBuyTimestamp(newBuyTimestampAccount, accountBalance, desiredAmountToMintOrBurn);
            
            IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
                IDefiFactoryToken(defiFactoryTokenAddress).getUtilsContractAtPos(DEFT_STORAGE_CONTRACT_ID)
            );
            iDeftStorageContract.updateBuyTimestamp(defiFactoryTokenAddress, account, newBuyTimestampAccount);
        } else
        {
            realTotalSupply -= desiredAmountToMintOrBurn;
        }
        
        return desiredAmountToMintOrBurn;
    }
    
    function getBalance(address , uint accountBalance)
        external
        onlyRole(ROLE_ADMIN)
        view
        returns(uint)
    {
        return accountBalance;
    }
    
    function getRealBalanceTeamVestingContract(uint accountBalance)
        external
        onlyRole(ROLE_ADMIN)
        view
        returns(uint)
    {
        return accountBalance;
    }
}