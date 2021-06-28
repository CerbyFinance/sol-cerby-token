// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.4;

import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/INoBotsTech.sol";
import "./interfaces/IWeth.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IDeftStorageContract.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";



contract NoBotsTechV2 is AccessControlEnumerable {
    
    uint constant DEFT_STORAGE_CONTRACT_ID = 3;
    uint constant UNISWAP_V2_PAIR_ADDRESS_ID = 4;
    
    
    address UNISWAP_V2_FACTORY_ADDRESS;
    address WETH_TOKEN_ADDRESS;
    
    uint constant BALANCE_MULTIPLIER_DENORM = 1e18;
    uint public cachedMultiplier = BALANCE_MULTIPLIER_DENORM;
    
    
    uint public batchBurnAndReward;
    uint public lastCachedTimestamp = block.timestamp;
    uint public lastPaidFeeTimestamp;
    
    uint public secondsBetweenRecacheUpdates = 0;
    
    
    address public defiFactoryTokenAddress = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840;
    address public parentTokenAddress;
    
    
    uint public botTaxPercent = 999e3; // 99.9%
    uint public howManyFirstMinutesIncreasedTax = 0;
    uint constant TAX_PERCENT_DENORM = 1e6;
    
    uint public cycleOneStartTaxPercent = 15e4; // 15.0%
    uint public cycleOneEnds = 120 days;
    
    uint public cycleTwoStartTaxPercent = 8e4; // 8.0%
    uint public cycleTwoEnds = 240 days;
    
    uint public cycleThreeStartTaxPercent = 3e4; // 3.0%
    uint public cycleThreeEnds = 360 days;
    uint public cycleThreeEndTaxPercent = 0; // 0.0%
    
    uint public buyLimitAmount = 1e18 * 1e18; // no limit
    uint public buyLimitPercent = TAX_PERCENT_DENORM; // 100% means disabled
    
    
    address constant BURN_ADDRESS = address(0x0);
    address constant DEFT_ADDRESS = address(0xdef7);
    
    uint public rewardsBalance;
    uint public realTotalSupply;
    uint public realAmountToPayDeftFee = 1e18*1e6; // TODO: remove on production
    uint public earlyInvestorTimestamp;
    
    
    struct CurrectCycle {
        uint currentCycleTax;
        uint howMuchTimeLeftTillEndOfCycleThree;
    }
    
    
    event MultiplierUpdated(uint newMultiplier);
    event BotTransactionDetected(address from, address to, uint transferAmount, uint taxedAmount);
    event BuyLimitAmountUpdated(uint newBuyLimitAmount);
    
    constructor() {
        _setupRole(ROLE_ADMIN, _msgSender());
        _setupRole(ROLE_ADMIN, defiFactoryTokenAddress);
        
        if (block.chainid == 1)
        {
            earlyInvestorTimestamp = 1621846800;
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            WETH_TOKEN_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        } else if (block.chainid == 56)
        {
            earlyInvestorTimestamp = 1623633960;
            UNISWAP_V2_FACTORY_ADDRESS = 0xBCfCcbde45cE874adCB698cC183deBcF17952812;
            WETH_TOKEN_ADDRESS = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        } else if (block.chainid == 42)
        {
            earlyInvestorTimestamp = block.timestamp;
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            WETH_TOKEN_ADDRESS = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
            
            parentTokenAddress = 0xC0138126C0Bd394C547df17B649B81B543c76906;
        }
        
        emit MultiplierUpdated(cachedMultiplier);
    }
    
    function updateSupply(uint _realTotalSupply, uint _rewardsBalance)
        external
        onlyRole(ROLE_ADMIN)
    {
        realTotalSupply = _realTotalSupply;
        rewardsBalance = _rewardsBalance;
        
        cachedMultiplier = BALANCE_MULTIPLIER_DENORM + 
                (BALANCE_MULTIPLIER_DENORM * rewardsBalance) / realTotalSupply;
        emit MultiplierUpdated(cachedMultiplier);
    }
        
    
    function updateBuyLimitPercent(uint _buyLimitPercent)
        external
        onlyRole(ROLE_ADMIN)
    {
        buyLimitPercent = _buyLimitPercent;
    }
    
    function updateDefiFactoryTokenAddress(address _defiFactoryTokenAddress)
        external
        onlyRole(ROLE_ADMIN)
    {
        defiFactoryTokenAddress = _defiFactoryTokenAddress;
    }
    
    function updateParentTokenAddress(address _parentTokenAddress)
        external
        onlyRole(ROLE_ADMIN)
    {
        parentTokenAddress = _parentTokenAddress;
    }
    
    function updateSecondsBetweenUpdates(uint _secondsBetweenRecacheUpdates)
        external
        onlyRole(ROLE_ADMIN)
    {
        secondsBetweenRecacheUpdates = _secondsBetweenRecacheUpdates;
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
        if (
                block.timestamp > lastCachedTimestamp + secondsBetweenRecacheUpdates ||
                tx.gasprice == 0 && block.timestamp > lastCachedTimestamp // Increasing gas limit for estimates to avoide out of gas error
            )
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
            uint realAmountToPayFeeThisTime = (batchBurnAndReward * 25e4) / TAX_PERCENT_DENORM; // 25% of tax goes to DEFT
            realAmountToPayDeftFee += realAmountToPayFeeThisTime;
            
            // 75% Tax redistribution
            rewardsBalance += batchBurnAndReward - realAmountToPayFeeThisTime; // 75% of amount goes to rewards to TOKEN holders
            realTotalSupply -= batchBurnAndReward;
            batchBurnAndReward = 0;
            
            cachedMultiplier = BALANCE_MULTIPLIER_DENORM + 
                (BALANCE_MULTIPLIER_DENORM * rewardsBalance) / realTotalSupply;
            
            emit MultiplierUpdated(cachedMultiplier);
            
            IUniswapV2Pair(
                IDefiFactoryToken(defiFactoryTokenAddress).
                    getUtilsContractAtPos(UNISWAP_V2_PAIR_ADDRESS_ID)
            ).sync();
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
    
    function payFeeToDeftHolders()
        public
    {
        if  (
                parentTokenAddress != BURN_ADDRESS &&
                realAmountToPayDeftFee > 1 &&
                block.timestamp > lastPaidFeeTimestamp + 0 minutes
            )
        {
            address sellPair = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).getPair(defiFactoryTokenAddress, WETH_TOKEN_ADDRESS);
            address buyPair = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).getPair(WETH_TOKEN_ADDRESS, parentTokenAddress);
            
            // Paying 25% fee to DEFT holders
            uint amountIn = (realAmountToPayDeftFee * cachedMultiplier) / BALANCE_MULTIPLIER_DENORM; // 25% to DEFT holders
            IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryTokenAddress);
            iDefiFactoryToken.mintHumanAddress(sellPair, amountIn);
            
            realAmountToPayDeftFee = 0;
            
            // Sell Lambo
            (uint reserveIn, uint reserveOut,) = IUniswapV2Pair(sellPair).getReserves();
            if (defiFactoryTokenAddress > WETH_TOKEN_ADDRESS)
            {
                (reserveIn, reserveOut) = (reserveOut, reserveIn);
            }
            
            uint amountInWithFee = amountIn * 997;
            uint numerator = amountInWithFee * reserveOut;
            uint denominator = reserveIn * 1000 + amountInWithFee;
            uint amountOut = numerator / denominator;
            
            (uint amount0Out, uint amount1Out) = defiFactoryTokenAddress < WETH_TOKEN_ADDRESS? 
                (uint(0), amountOut): (amountOut, uint(0));
            
            IUniswapV2Pair(sellPair).swap(
                amount0Out, 
                amount1Out, 
                buyPair, 
                new bytes(0)
            );
            
            
            // Buy deft
            (reserveIn, reserveOut,) = IUniswapV2Pair(buyPair).getReserves();
            if (WETH_TOKEN_ADDRESS > parentTokenAddress)
            {
                (reserveIn, reserveOut) = (reserveOut, reserveIn);
            }
            
            amountInWithFee = amountOut * 997;
            numerator = amountInWithFee * reserveOut;
            denominator = reserveIn * 1000 + amountInWithFee;
            amountOut = numerator / denominator;
            
            (amount0Out, amount1Out) = WETH_TOKEN_ADDRESS < parentTokenAddress?
                (uint(0), amountOut): (amountOut, uint(0));
            
            IUniswapV2Pair(buyPair).swap(
                amount0Out, 
                amount1Out, 
                address(this), 
                new bytes(0)
            );
            
            uint amountToRedistribute = IDefiFactoryToken(parentTokenAddress).balanceOf(address(this));
            IDefiFactoryToken(parentTokenAddress).
                burnHumanAddress(
                        address(this), 
                        amountToRedistribute
                    );
                    
            rewardsBalance += (amountToRedistribute * BALANCE_MULTIPLIER_DENORM) / cachedMultiplier;
            
            cachedMultiplier = BALANCE_MULTIPLIER_DENORM + 
                (BALANCE_MULTIPLIER_DENORM * rewardsBalance) / realTotalSupply;
            
            emit MultiplierUpdated(cachedMultiplier);
            
            IUniswapV2Pair(
                IDefiFactoryToken(defiFactoryTokenAddress).
                    getUtilsContractAtPos(UNISWAP_V2_PAIR_ADDRESS_ID)
            ).sync();
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
        
        IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
                IDefiFactoryToken(defiFactoryTokenAddress).getUtilsContractAtPos(DEFT_STORAGE_CONTRACT_ID)
            );
        IsHumanInfo memory isHumanInfo = iDeftStorageContract.isHumanTransaction(defiFactoryTokenAddress, taxAmountsInput.sender, taxAmountsInput.recipient);
        
        if (buyLimitPercent < TAX_PERCENT_DENORM)
        {
            require (
                !isHumanInfo.isBuy ||
                isHumanInfo.isBuy &&
                taxAmountsInput.transferAmount < buyLimitAmount,
                "NBT: !buy_limit"
            );
        }
        
        uint buyTimestampSender = 
            getUpdatedBuyTimestampOfEarlyInvestor(taxAmountsInput.sender, taxAmountsInput.senderRealBalance);
        uint timePassedSinceLastBuy = block.timestamp > buyTimestampSender?
                                        block.timestamp - buyTimestampSender: 0;
        
        uint burnAndRewardRealAmount;
        if (isHumanInfo.isHumanTransaction)
        {
            if (isHumanInfo.isSell)
            {
                // human on main pair
                // buys - 0% tax
                // sells - cycle tax
                // transfers - 0% tax
                
                uint cycleTaxPercent = calculateCurrentCycleTax(timePassedSinceLastBuy);
                burnAndRewardRealAmount = (realTransferAmount * cycleTaxPercent) / TAX_PERCENT_DENORM;
            }
        } else
        {
            burnAndRewardRealAmount = (realTransferAmount * botTaxPercent) / TAX_PERCENT_DENORM;
            
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
            newBuyTimestamp = getNewBuyTimestamp(newBuyTimestamp, taxAmountsInput.recipientRealBalance, realTransferAmount);
            
            iDeftStorageContract.updateBuyTimestamp(defiFactoryTokenAddress, taxAmountsInput.recipient, newBuyTimestamp);
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
        
        if (!isHumanInfo.isSell && !isHumanInfo.isBuy) // TODO: test isBuy only
        { // isTransfer
            payFeeToDeftHolders();
        }
        
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
        } else if (accountBalance != 0)
        {
            newBuyTimestamp = earlyInvestorTimestamp;
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
        uint realAmountToMintOrBurn = (BALANCE_MULTIPLIER_DENORM * desiredAmountToMintOrBurn) / cachedMultiplier;
        uint rewardToMintOrBurn = desiredAmountToMintOrBurn - realAmountToMintOrBurn;
        if (isMint) 
        {
            rewardsBalance += rewardToMintOrBurn;
            realTotalSupply += realAmountToMintOrBurn;
            
            uint accountBalance = IDefiFactoryToken(defiFactoryTokenAddress).balanceOf(account);
            uint newBuyTimestampAccount = getUpdatedBuyTimestampOfEarlyInvestor(account, accountBalance);
            newBuyTimestampAccount = getNewBuyTimestamp(newBuyTimestampAccount, accountBalance, desiredAmountToMintOrBurn);
            
            IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
                IDefiFactoryToken(defiFactoryTokenAddress).getUtilsContractAtPos(DEFT_STORAGE_CONTRACT_ID)
            );
            iDeftStorageContract.updateBuyTimestamp(defiFactoryTokenAddress, account, newBuyTimestampAccount);
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
        IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
            IDefiFactoryToken(defiFactoryTokenAddress).getUtilsContractAtPos(DEFT_STORAGE_CONTRACT_ID)
        );
        return iDeftStorageContract.isExcludedFromBalance(account)? accountBalance:
            (accountBalance * cachedMultiplier) / BALANCE_MULTIPLIER_DENORM;
    }
    
    function getRealBalance(address account, uint accountBalance)
        external
        onlyRole(ROLE_ADMIN)
        view
        returns(uint)
    {
        IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
            IDefiFactoryToken(defiFactoryTokenAddress).getUtilsContractAtPos(DEFT_STORAGE_CONTRACT_ID)
        );
        return iDeftStorageContract.isExcludedFromBalance(account)? accountBalance:
            (accountBalance * BALANCE_MULTIPLIER_DENORM) / cachedMultiplier;
    }
    
    function getRealBalanceTeamVestingContract(uint accountBalance)
        external
        onlyRole(ROLE_ADMIN)
        view
        returns(uint)
    {
        return (accountBalance * BALANCE_MULTIPLIER_DENORM) / cachedMultiplier;
    }
}