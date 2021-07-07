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
    uint public lastPaidFeeTimestamp = block.timestamp;
    
    uint public secondsBetweenCacheUpdates = 10 minutes;
    uint public howOftenToPayFee = 30 minutes; // TODO: change in production
    
    
    address public defiFactoryTokenAddress;
    address public parentTokenAddress;
    
    uint public botTaxPercent = 999e3; // 99.9%
    uint constant TAX_PERCENT_DENORM = 1e6;
    
    /* DEFT Taxes: */
    /*
    uint public constant DEFT_FEE_PERCENT = 0; // 0.0%
    uint public cycleOneStartTaxPercent = 15e4; // 15.0%
    uint public cycleOneEnds = 120 days;
    uint public cycleTwoStartTaxPercent = 8e4; // 8.0%
    uint public cycleTwoEnds = 240 days;
    uint public cycleThreeStartTaxPercent = 3e4; // 3.0%
    uint public cycleThreeEnds = 360 days;
    uint public cycleThreeEndTaxPercent = 0; // 0.0% */
    
    /* Lambo Taxes */
    uint public constant DEFT_FEE_PERCENT = 10e4; // 10.0%
    uint public cycleOneStartTaxPercent = 30e4; // 30.0%
    uint public cycleOneEnds = 0 days;
    uint public cycleTwoStartTaxPercent = 30e4; // 30.0%
    uint public cycleTwoEnds = 0 days;
    uint public cycleThreeStartTaxPercent = 30e4; // 30.0%
    uint public cycleThreeEnds = 0 days;
    uint public cycleThreeEndTaxPercent = 0; // 5.0%
    
    uint public buyLimitAmount = 1e18 * 1e18; // no limit
    uint public buyLimitPercent = TAX_PERCENT_DENORM; // 100% means disabled
    
    uint public MINIMUM_WETH_IN_LIQUIDITY_TO_PAY_FEE;
    
    uint constant ETH_MAINNET_CHAIN_ID = 1;
    uint constant ETH_ROPSTEN_CHAIN_ID = 3;
    uint constant ETH_KOVAN_CHAIN_ID = 42;
    uint constant BSC_MAINNET_CHAIN_ID = 56;
    uint constant BSC_TESTNET_CHAIN_ID = 97;
    
    address constant BURN_ADDRESS = address(0x0);
    address constant DEFT_TRACKING_ADDRESS = 0x1111111100000000000000000000000000000000;
    address constant DEAD_ADDRESS = 0xdEad000000000000000000000000000000000000;
    
    uint public rewardsBalance;
    uint public realTotalSupply;
    uint public earlyInvestorTimestamp;
    
    uint creationBlockNumber;
    
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
        
        creationBlockNumber = block.number;
        
        if (block.chainid == ETH_MAINNET_CHAIN_ID)
        {
            //earlyInvestorTimestamp = 1621846800; // DEFT
            earlyInvestorTimestamp = block.timestamp;
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            WETH_TOKEN_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
            MINIMUM_WETH_IN_LIQUIDITY_TO_PAY_FEE = 10e18;
            
            parentTokenAddress = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840; // DEFT
        } else if (block.chainid == BSC_MAINNET_CHAIN_ID)
        {
            //earlyInvestorTimestamp = 1623633960; // DEFT
            earlyInvestorTimestamp = block.timestamp;
            UNISWAP_V2_FACTORY_ADDRESS = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
            WETH_TOKEN_ADDRESS = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
            MINIMUM_WETH_IN_LIQUIDITY_TO_PAY_FEE = 75e18;
            
            parentTokenAddress = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840; // DEFT
        } else if (block.chainid == ETH_KOVAN_CHAIN_ID)
        {
            earlyInvestorTimestamp = block.timestamp;
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            WETH_TOKEN_ADDRESS = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
            MINIMUM_WETH_IN_LIQUIDITY_TO_PAY_FEE = 1e6;
            
            parentTokenAddress = 0xa1EDE2C6D2b36853cc967E04bB4fF39f55eDa885;
        }
        
        emit MultiplierUpdated(cachedMultiplier);
    }
    
    function updateHowOftenToPayFee(uint _value)
        external
        onlyRole(ROLE_ADMIN)
    {
        require(_value < 1 days, "NBT: Value can't be larger than 1 day");
        
        howOftenToPayFee = _value;
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
    
    function updateSecondsBetweenCacheUpdates(uint _value)
        external
        onlyRole(ROLE_ADMIN)
    {
        require(_value < 1 days, "NBT: Value can't be larger than 1 day");
        
        secondsBetweenCacheUpdates = _value;
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
                block.timestamp > lastCachedTimestamp + secondsBetweenCacheUpdates/* ||
                tx.gasprice == 0 && block.timestamp > lastCachedTimestamp*/ // Increasing gas limit for estimates to avoid out of gas error
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
            uint realAmountToPayFeeThisTime = (batchBurnAndReward * DEFT_FEE_PERCENT) / TAX_PERCENT_DENORM;
            rewardsBalance += batchBurnAndReward - realAmountToPayFeeThisTime;
            realTotalSupply -= batchBurnAndReward;
            batchBurnAndReward = 0;
                
            uint amountToPayFeeThisTime = (realAmountToPayFeeThisTime * cachedMultiplier) / BALANCE_MULTIPLIER_DENORM;
            mintAmountAndUpdateTotalSupply(DEFT_TRACKING_ADDRESS, amountToPayFeeThisTime, realAmountToPayFeeThisTime);
            
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
    
    function mintAmountAndUpdateTotalSupply(address addr, uint amount, uint realAmount)
        public
        onlyRole(ROLE_ADMIN)
    {
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryTokenAddress);
        iDefiFactoryToken.mintHumanAddress(addr, amount);
        
        uint extraTotalSupply = (amount - realAmount);
        uint extraRealTotalSupply = (extraTotalSupply * BALANCE_MULTIPLIER_DENORM) / cachedMultiplier;
        realTotalSupply -= extraRealTotalSupply;
        rewardsBalance -= extraTotalSupply - extraRealTotalSupply;
    }
    
    function publicForcedUpdateCacheMultiplier()
        public
    {   
        if (block.timestamp > lastCachedTimestamp)
        {
            forcedUpdateCache();
        }
    }
    
    function payAllFees()
        public
    {
        if (block.timestamp > lastPaidFeeTimestamp + howOftenToPayFee)
        {
            lastPaidFeeTimestamp = block.timestamp;
            
            payFeeToDeftHolders();
            //payFeeTo(MARKETING_TRACKING_ADDRESS, marketingWallet);
            //payFeeTo(BUY_BACK_TRACKING_ADDRESS, buyBackWallet);
        }
    }
    
    function payFeeToDeftHolders()
        private
    {
        if  (parentTokenAddress != BURN_ADDRESS)
        {
            uint amountToPayDeftFee = IWeth(defiFactoryTokenAddress).balanceOf(DEFT_TRACKING_ADDRESS);
            if  (
                    amountToPayDeftFee > 1
                )
            {
                address sellPair = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).getPair(defiFactoryTokenAddress, WETH_TOKEN_ADDRESS);
                address buyPair = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).getPair(WETH_TOKEN_ADDRESS, parentTokenAddress);
                
                if (IWeth(WETH_TOKEN_ADDRESS).balanceOf(buyPair) <= MINIMUM_WETH_IN_LIQUIDITY_TO_PAY_FEE)
                {
                    return;
                }
                
                // Paying fee to DEFT holders
                uint amountIn = amountToPayDeftFee;
                IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryTokenAddress);
                iDefiFactoryToken.burnHumanAddress(DEFT_TRACKING_ADDRESS, amountIn);
                iDefiFactoryToken.mintHumanAddress(sellPair, amountIn);
                
                // Sell Token
                (uint reserveIn, uint reserveOut,) = IUniswapV2Pair(sellPair).getReserves();
                if (defiFactoryTokenAddress > WETH_TOKEN_ADDRESS)
                {
                    (reserveIn, reserveOut) = (reserveOut, reserveIn);
                }
                
                uint amountInWithFee = amountIn * 997;
                uint amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
                
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
                amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
                
                (amount0Out, amount1Out) = WETH_TOKEN_ADDRESS < parentTokenAddress?
                    (uint(0), amountOut): (amountOut, uint(0));
                
                IUniswapV2Pair(buyPair).swap(
                    amount0Out, 
                    amount1Out, 
                    DEAD_ADDRESS, 
                    new bytes(0)
                );
            }
        }
    }
    
    function payFeeTo(address fromTrackingAddress, address toAddress)
        private
    {
        if  (fromTrackingAddress != toAddress)
        {
            uint amountToPayDeftFee = IWeth(defiFactoryTokenAddress).balanceOf(fromTrackingAddress);
            if (
                    amountToPayDeftFee > 1 &&
                    block.timestamp > lastPaidFeeTimestamp + howOftenToPayFee
                )
            {
                address sellPair = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).getPair(defiFactoryTokenAddress, WETH_TOKEN_ADDRESS);
                
                uint amountIn = amountToPayDeftFee;
                IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryTokenAddress);
                iDefiFactoryToken.burnHumanAddress(fromTrackingAddress, amountIn);
                iDefiFactoryToken.mintHumanAddress(sellPair, amountIn);
                
                // Sell Token
                (uint reserveIn, uint reserveOut,) = IUniswapV2Pair(sellPair).getReserves();
                if (defiFactoryTokenAddress > WETH_TOKEN_ADDRESS)
                {
                    (reserveIn, reserveOut) = (reserveOut, reserveIn);
                }
                
                uint amountInWithFee = amountIn * 997;
                uint amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
                
                (uint amount0Out, uint amount1Out) = defiFactoryTokenAddress < WETH_TOKEN_ADDRESS? 
                    (uint(0), amountOut): (amountOut, uint(0));
                
                IUniswapV2Pair(sellPair).swap(
                    amount0Out, 
                    amount1Out, 
                    toAddress, 
                    new bytes(0)
                );
            }
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
                burnAndRewardRealAmount = (realTransferAmount * cycleTaxPercent) / TAX_PERCENT_DENORM;
            }
            
            /*if (
                    isHumanInfo.isBuy
                )
            {
                uint buyTimestampRecipient = 
                    getUpdatedBuyTimestampOfEarlyInvestor(taxAmountsInput.recipient, taxAmountsInput.recipientRealBalance);
                uint timePassedSinceLastBuy = 
                    block.timestamp > buyTimestampRecipient? block.timestamp - buyTimestampRecipient: 0;
                uint cycleTaxPercent = calculateCurrentCycleTax(timePassedSinceLastBuy);
                burnAndRewardRealAmount = (realTransferAmount * cycleTaxPercent) / TAX_PERCENT_DENORM;
            }*/
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
            
            if (!isHumanInfo.isBuy) // isTransfer
            {
                payAllFees();
            }
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
        if (account <= address(0xfffff) && account != address(0xdead)) return 1;
        
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