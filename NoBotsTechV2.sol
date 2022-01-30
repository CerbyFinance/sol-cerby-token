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
    uint256 constant DEFT_STORAGE_CONTRACT_ID = 3;
    uint256 constant UNISWAP_V2_PAIR_ADDRESS_ID = 4;

    address UNISWAP_V2_FACTORY_ADDRESS;
    address WETH_TOKEN_ADDRESS;

    uint256 constant BALANCE_MULTIPLIER_DENORM = 1e18;
    uint256 public cachedMultiplier = BALANCE_MULTIPLIER_DENORM;

    uint256 public batchBurnAndReward;
    uint256 public lastCachedTimestamp = block.timestamp;
    uint256 public lastPaidFeeTimestamp = block.timestamp;

    uint256 public secondsBetweenCacheUpdates = 10 minutes; // TODO: change in production
    uint256 public howOftenToPayFee = 36500 days; // TODO: change in production

    address public defiFactoryTokenAddress =
        0xdef1fac7Bf08f173D286BbBDcBeeADe695129840;
    address public parentTokenAddress;

    uint256 public botTaxPercent = 9999e2; // 99.99%
    uint256 constant TAX_PERCENT_DENORM = 1e6;

    /* DEFT Taxes: */
    uint256 public constant DEFT_FEE_PERCENT = 0; // 0.0%
    uint256 public cycleOneStartTaxPercent = 15e4; // 15.0%
    uint256 public cycleOneEnds = 120 days;
    uint256 public cycleTwoStartTaxPercent = 8e4; // 8.0%
    uint256 public cycleTwoEnds = 240 days;
    uint256 public cycleThreeStartTaxPercent = 3e4; // 3.0%
    uint256 public cycleThreeEnds = 360 days;
    uint256 public cycleThreeEndTaxPercent = 0; // 0.0%

    /* Lambo Taxes */
    /*uint public constant DEFT_FEE_PERCENT = 10e4; // 10.0%
    uint public cycleOneStartTaxPercent = 30e4; // 30.0%
    uint public cycleOneEnds = 0 days;
    uint public cycleTwoStartTaxPercent = 30e4; // 30.0%
    uint public cycleTwoEnds = 0 days;
    uint public cycleThreeStartTaxPercent = 30e4; // 30.0%
    uint public cycleThreeEnds = 7 days;
    uint public cycleThreeEndTaxPercent = 5e4; // 5.0%*/

    uint256 public buyLimitAmount = 1e18 * 1e18; // no limit
    uint256 public buyLimitPercent = TAX_PERCENT_DENORM; // 100e4 = 100% means disabled

    uint256 constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 constant ETH_ROPSTEN_CHAIN_ID = 3;
    uint256 constant ETH_KOVAN_CHAIN_ID = 42;
    uint256 constant BSC_MAINNET_CHAIN_ID = 56;
    uint256 constant BSC_TESTNET_CHAIN_ID = 97;

    address constant BURN_ADDRESS = address(0x0);
    address constant DEFT_TRACKING_ADDRESS =
        0x1111111100000000000000000000000000000000;
    address constant DEAD_ADDRESS = 0xdEad000000000000000000000000000000000000;

    uint256 public rewardsBalance;
    uint256 public realTotalSupply;
    uint256 public earlyInvestorTimestamp;

    struct CurrectCycle {
        uint256 currentCycleTax;
        uint256 howMuchTimeLeftTillEndOfCycleThree;
    }

    event MultiplierUpdated(uint256 newMultiplier);
    event BotTransactionDetected(
        address from,
        address to,
        uint256 transferAmount,
        uint256 taxedAmount
    );
    event BuyLimitAmountUpdated(uint256 newBuyLimitAmount);

    constructor() {
        _setupRole(ROLE_ADMIN, _msgSender());
        _setupRole(ROLE_ADMIN, defiFactoryTokenAddress);

        if (block.chainid == ETH_MAINNET_CHAIN_ID) {
            earlyInvestorTimestamp = 1621846800; // DEFT
            //earlyInvestorTimestamp = block.timestamp;
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            WETH_TOKEN_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

            //defiFactoryTokenAddress = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840;
            //parentTokenAddress = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840; // DEFT
        } else if (block.chainid == BSC_MAINNET_CHAIN_ID) {
            earlyInvestorTimestamp = 1623633960; // DEFT
            //earlyInvestorTimestamp = block.timestamp;
            UNISWAP_V2_FACTORY_ADDRESS = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
            WETH_TOKEN_ADDRESS = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

            rewardsBalance = 0;
            realTotalSupply = 0;

            //defiFactoryTokenAddress = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840;
            //parentTokenAddress = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840; // DEFT
        } /* else if (block.chainid == ETH_KOVAN_CHAIN_ID)
        {
            earlyInvestorTimestamp = block.timestamp;
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            WETH_TOKEN_ADDRESS = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
            
            parentTokenAddress = 0xa1EDE2C6D2b36853cc967E04bB4fF39f55eDa885;
        }*/

        cachedMultiplier = realTotalSupply == 0
            ? BALANCE_MULTIPLIER_DENORM
            : BALANCE_MULTIPLIER_DENORM +
                (BALANCE_MULTIPLIER_DENORM * rewardsBalance) /
                realTotalSupply;
        emit MultiplierUpdated(cachedMultiplier);
    }

    function updateHowOftenPayDeftFee(uint256 _value)
        external
        onlyRole(ROLE_ADMIN)
    {
        //require(_value < 1 days, "NBT: Value can't be larger than 1 day");

        howOftenToPayFee = _value;
    }

    function updateSupply(uint256 _realTotalSupply, uint256 _rewardsBalance)
        external
        onlyRole(ROLE_ADMIN)
    {
        realTotalSupply = _realTotalSupply;
        rewardsBalance = _rewardsBalance;

        cachedMultiplier = realTotalSupply == 0
            ? BALANCE_MULTIPLIER_DENORM
            : BALANCE_MULTIPLIER_DENORM +
                (BALANCE_MULTIPLIER_DENORM * rewardsBalance) /
                realTotalSupply;
        emit MultiplierUpdated(cachedMultiplier);
    }

    function updateBuyLimitPercent(uint256 _buyLimitPercent)
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

    function updateSecondsBetweenCacheUpdates(uint256 _value)
        external
        onlyRole(ROLE_ADMIN)
    {
        //require(_value < 1 days, "NBT: Value can't be larger than 1 day");

        secondsBetweenCacheUpdates = _value;
    }

    function updateBotTaxSettings(uint256 _botTaxPercent)
        external
        onlyRole(ROLE_ADMIN)
    {
        botTaxPercent = _botTaxPercent;
    }

    function updateCycleOneSettings(
        uint256 _cycleOneStartTaxPercent,
        uint256 _cycleOneEnds
    ) external onlyRole(ROLE_ADMIN) {
        cycleOneStartTaxPercent = _cycleOneStartTaxPercent;
        cycleOneEnds = _cycleOneEnds;
    }

    function updateCycleTwoSettings(
        uint256 _cycleTwoStartTaxPercent,
        uint256 _cycleTwoEnds
    ) external onlyRole(ROLE_ADMIN) {
        cycleTwoStartTaxPercent = _cycleTwoStartTaxPercent;
        cycleTwoEnds = _cycleTwoEnds;
    }

    function updateCycleThreeSettings(
        uint256 _cycleThreeStartTaxPercent,
        uint256 _cycleThreeEnds,
        uint256 _cycleThreeEndTaxPercent
    ) external onlyRole(ROLE_ADMIN) {
        cycleThreeStartTaxPercent = _cycleThreeStartTaxPercent;
        cycleThreeEnds = _cycleThreeEnds;
        cycleThreeEndTaxPercent = _cycleThreeEndTaxPercent;
    }

    function getTotalSupply()
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint256)
    {
        return realTotalSupply + rewardsBalance;
    }

    function getRewardsBalance()
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint256)
    {
        return rewardsBalance;
    }

    function delayedUpdateCache() private {
        if (
            block.timestamp >
            lastCachedTimestamp + secondsBetweenCacheUpdates ||
            (tx.gasprice == 0 && block.timestamp > lastCachedTimestamp) // Increasing gas limit for estimates to avoid out of gas error
        ) {
            forcedUpdateCache();
        }
    }

    function forcedUpdateCache() private {
        lastCachedTimestamp = block.timestamp;

        if (batchBurnAndReward > 0) {
            /*
            uint realAmountToPayFeeThisTime = (batchBurnAndReward * DEFT_FEE_PERCENT) / TAX_PERCENT_DENORM;
            rewardsBalance += batchBurnAndReward - realAmountToPayFeeThisTime;
            realTotalSupply -= batchBurnAndReward;
            uint amountToPayFeeThisTime = (realAmountToPayFeeThisTime * cachedMultiplier) / BALANCE_MULTIPLIER_DENORM;
            mintAndUpdateTotalSupply(DEFT_TRACKING_ADDRESS, amountToPayFeeThisTime, realAmountToPayFeeThisTime);
            */

            rewardsBalance += batchBurnAndReward;
            realTotalSupply -= batchBurnAndReward;
            batchBurnAndReward = 0;

            cachedMultiplier =
                BALANCE_MULTIPLIER_DENORM +
                (BALANCE_MULTIPLIER_DENORM * rewardsBalance) /
                realTotalSupply;
            emit MultiplierUpdated(cachedMultiplier);

            IUniswapV2Pair(
                IDefiFactoryToken(defiFactoryTokenAddress)
                    .getUtilsContractAtPos(UNISWAP_V2_PAIR_ADDRESS_ID)
            ).sync();
        }

        /*if (buyLimitPercent < TAX_PERCENT_DENORM)
        {
            address pairAddress = IDefiFactoryToken(defiFactoryTokenAddress).
                    getUtilsContractAtPos(UNISWAP_V2_PAIR_ADDRESS_ID);
            uint deftBalance = IWeth(defiFactoryTokenAddress).balanceOf(pairAddress);
            buyLimitAmount = (deftBalance * buyLimitPercent) / TAX_PERCENT_DENORM;
            
            emit BuyLimitAmountUpdated(buyLimitAmount);
        }*/
    }

    /*function mintAmountAndUpdateTotalSupply(address addr, uint amount, uint realAmount)
        private
        onlyRole(ROLE_ADMIN)
    {
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryTokenAddress);
        iDefiFactoryToken.mintHumanAddress(addr, amount);
        
        uint extraTotalSupply = (amount - realAmount);
        uint extraRealTotalSupply = (extraTotalSupply * BALANCE_MULTIPLIER_DENORM) / cachedMultiplier;
        realTotalSupply -= extraRealTotalSupply;
        rewardsBalance -= extraTotalSupply - extraRealTotalSupply;
    }*/

    function publicForcedUpdateCacheMultiplier() public {
        if (block.timestamp > lastCachedTimestamp) {
            forcedUpdateCache();
        }
    }

    /*function payAllFees()
        public
    {
        if (block.timestamp > lastPaidFeeTimestamp + howOftenToPayFee)
        {
            lastPaidFeeTimestamp = block.timestamp;
            
            //payFeeTo(MARKETING_TRACKING_ADDRESS, marketingWallet);
            //payFeeTo(BUY_BACK_TRACKING_ADDRESS, buyBackWallet);
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
    }*/

    function chargeCustomTax(uint256 taxAmount, uint256 accountBalance)
        external
        onlyRole(ROLE_ADMIN)
        returns (uint256)
    {
        uint256 realTaxAmount = (taxAmount * BALANCE_MULTIPLIER_DENORM) /
            cachedMultiplier;

        accountBalance -= realTaxAmount;
        batchBurnAndReward += realTaxAmount;

        delayedUpdateCache();

        return accountBalance;
    }

    function prepareTaxAmounts(TaxAmountsInput calldata taxAmountsInput)
        external
        onlyRole(ROLE_ADMIN)
        returns (TaxAmountsOutput memory taxAmountsOutput)
    {
        uint256 realTransferAmount = (taxAmountsInput.transferAmount *
            BALANCE_MULTIPLIER_DENORM) / cachedMultiplier;

        require(realTransferAmount > 0, "NBT: !amount");

        IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
            IDefiFactoryToken(defiFactoryTokenAddress).getUtilsContractAtPos(
                DEFT_STORAGE_CONTRACT_ID
            )
        );
        IsHumanInfo memory isHumanInfo = iDeftStorageContract
            .isHumanTransaction(
                defiFactoryTokenAddress,
                taxAmountsInput.sender,
                taxAmountsInput.recipient
            );

        if (buyLimitPercent < TAX_PERCENT_DENORM) {
            require(
                !isHumanInfo.isBuy ||
                    (isHumanInfo.isBuy &&
                        taxAmountsInput.transferAmount < buyLimitAmount),
                "NBT: !buy_limit"
            );
        }

        uint256 burnAndRewardRealAmount;
        if (isHumanInfo.isHumanTransaction) {
            // human on main pair
            // buys - 0% tax
            // sells - cycle tax
            // transfers - 0% tax

            if (isHumanInfo.isSell) {
                uint256 buyTimestampSender = getUpdatedBuyTimestampOfEarlyInvestor(
                        taxAmountsInput.sender,
                        taxAmountsInput.senderRealBalance
                    );
                uint256 timePassedSinceLastBuy = block.timestamp >
                    buyTimestampSender
                    ? block.timestamp - buyTimestampSender
                    : 0;
                uint256 cycleTaxPercent = calculateCurrentCycleTax(
                    timePassedSinceLastBuy
                );
                burnAndRewardRealAmount =
                    (realTransferAmount * cycleTaxPercent) /
                    TAX_PERCENT_DENORM;
            }
        } else {
            burnAndRewardRealAmount =
                (realTransferAmount * botTaxPercent) /
                TAX_PERCENT_DENORM;

            uint256 botTaxedAmount = (taxAmountsInput.transferAmount *
                botTaxPercent) / TAX_PERCENT_DENORM;
            emit BotTransactionDetected(
                taxAmountsInput.sender,
                taxAmountsInput.recipient,
                taxAmountsInput.transferAmount,
                botTaxedAmount
            );
        }

        if (!isHumanInfo.isSell) {
            // isBuy or isTransfer: Updating cycle based on realTransferAmount
            uint256 newBuyTimestamp = getUpdatedBuyTimestampOfEarlyInvestor(
                taxAmountsInput.recipient,
                taxAmountsInput.recipientRealBalance
            );
            newBuyTimestamp = getNewBuyTimestamp(
                newBuyTimestamp,
                taxAmountsInput.recipientRealBalance,
                realTransferAmount
            );

            iDeftStorageContract.updateBuyTimestamp(
                defiFactoryTokenAddress,
                taxAmountsInput.recipient,
                newBuyTimestamp
            );

            if (!isHumanInfo.isBuy) {
                // isTransfer
                delayedUpdateCache();
                //payAllFees();
            }
        }

        uint256 recipientGetsRealAmount = realTransferAmount -
            burnAndRewardRealAmount;
        taxAmountsOutput.senderRealBalance =
            taxAmountsInput.senderRealBalance -
            realTransferAmount;
        taxAmountsOutput.recipientRealBalance =
            taxAmountsInput.recipientRealBalance +
            recipientGetsRealAmount;
        batchBurnAndReward += burnAndRewardRealAmount;

        taxAmountsOutput.burnAndRewardAmount =
            (burnAndRewardRealAmount * cachedMultiplier) /
            BALANCE_MULTIPLIER_DENORM; // Actual amount we burned and have to show in event
        taxAmountsOutput.recipientGetsAmount =
            taxAmountsInput.transferAmount -
            taxAmountsOutput.burnAndRewardAmount; // Actual amount recipient got and have to show in event

        return taxAmountsOutput;
    }

    function calculateCurrentCycleTax(uint256 timePassedSinceLastBuy)
        private
        view
        returns (uint256)
    {
        if (timePassedSinceLastBuy > cycleThreeEnds) {
            return cycleThreeEndTaxPercent;
        } else if (timePassedSinceLastBuy > cycleTwoEnds) {
            return
                (cycleThreeStartTaxPercent *
                    (cycleThreeEnds - timePassedSinceLastBuy)) /
                (cycleThreeEnds - cycleTwoEnds);
        } else if (timePassedSinceLastBuy > cycleOneEnds) {
            return
                cycleTwoStartTaxPercent -
                ((cycleTwoStartTaxPercent - cycleThreeStartTaxPercent) *
                    (timePassedSinceLastBuy - cycleOneEnds)) /
                (cycleTwoEnds - cycleOneEnds);
        } else if (timePassedSinceLastBuy > 0) {
            return
                cycleOneStartTaxPercent -
                ((cycleOneStartTaxPercent - cycleTwoStartTaxPercent) *
                    timePassedSinceLastBuy) /
                cycleOneEnds;
        } else {
            return botTaxPercent;
        }
    }

    function getWalletCurrentCycle(address addr)
        external
        view
        returns (CurrectCycle memory currentCycle)
    {
        if (
            IDeftStorageContract(
                IDefiFactoryToken(defiFactoryTokenAddress)
                    .getUtilsContractAtPos(DEFT_STORAGE_CONTRACT_ID)
            ).isBotAddress(addr)
        ) {
            currentCycle.currentCycleTax = botTaxPercent;
            currentCycle.howMuchTimeLeftTillEndOfCycleThree = cycleThreeEnds;
        } else {
            uint256 accountBalance = IDefiFactoryToken(defiFactoryTokenAddress)
                .balanceOf(addr);
            uint256 buyTimestampAddr = getUpdatedBuyTimestampOfEarlyInvestor(
                addr,
                accountBalance
            );
            uint256 howMuchTimePassedSinceBuy = block.timestamp >
                buyTimestampAddr
                ? block.timestamp - buyTimestampAddr
                : 0;

            currentCycle.currentCycleTax = calculateCurrentCycleTax(
                howMuchTimePassedSinceBuy
            );
            currentCycle
                .howMuchTimeLeftTillEndOfCycleThree = howMuchTimePassedSinceBuy <
                cycleThreeEnds
                ? cycleThreeEnds - howMuchTimePassedSinceBuy
                : 0;
        }
        return currentCycle;
    }

    function getUpdatedBuyTimestampOfEarlyInvestor(
        address addr,
        uint256 accountBalance
    ) private view returns (uint256) {
        uint256 newBuyTimestamp = block.timestamp;

        IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
            IDefiFactoryToken(defiFactoryTokenAddress).getUtilsContractAtPos(
                DEFT_STORAGE_CONTRACT_ID
            )
        );

        uint256 buyTimeStampAddr = iDeftStorageContract.getBuyTimestamp(
            defiFactoryTokenAddress,
            addr
        );
        if (buyTimeStampAddr != 0) {
            newBuyTimestamp = buyTimeStampAddr;
        } else if (accountBalance > 0) {
            newBuyTimestamp = earlyInvestorTimestamp;
        }

        return newBuyTimestamp;
    }

    function getNewBuyTimestamp(
        uint256 currentTimestamp,
        uint256 accountBalance,
        uint256 receivedAmount
    ) private view returns (uint256) {
        uint256 timestampCycleThreeEnds = cycleThreeEnds + currentTimestamp;
        uint256 howManyDaysLeft = timestampCycleThreeEnds > block.timestamp
            ? timestampCycleThreeEnds - block.timestamp
            : 0;

        //weighted average between howManyDaysLeft and 365
        uint256 weightedAverageHowManyDaysLeft = (accountBalance *
            howManyDaysLeft +
            receivedAmount *
            cycleThreeEnds) / (accountBalance + receivedAmount);
        return
            currentTimestamp + weightedAverageHowManyDaysLeft - howManyDaysLeft;
    }

    function prepareHumanAddressMintOrBurnRewardsAmounts(
        bool isMint,
        address account,
        uint256 desiredAmountToMintOrBurn
    ) external onlyRole(ROLE_ADMIN) returns (uint256) {
        uint256 realAmountToMintOrBurn = (BALANCE_MULTIPLIER_DENORM *
            desiredAmountToMintOrBurn) / cachedMultiplier;
        uint256 rewardToMintOrBurn = desiredAmountToMintOrBurn -
            realAmountToMintOrBurn;
        if (isMint) {
            rewardsBalance += rewardToMintOrBurn;
            realTotalSupply += realAmountToMintOrBurn;

            uint256 accountBalance = IDefiFactoryToken(defiFactoryTokenAddress)
                .balanceOf(account);
            uint256 newBuyTimestampAccount = getUpdatedBuyTimestampOfEarlyInvestor(
                    account,
                    accountBalance
                );
            newBuyTimestampAccount = getNewBuyTimestamp(
                newBuyTimestampAccount,
                accountBalance,
                desiredAmountToMintOrBurn
            );

            IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
                IDefiFactoryToken(defiFactoryTokenAddress)
                    .getUtilsContractAtPos(DEFT_STORAGE_CONTRACT_ID)
            );
            iDeftStorageContract.updateBuyTimestamp(
                defiFactoryTokenAddress,
                account,
                newBuyTimestampAccount
            );
        } else {
            rewardsBalance -= rewardToMintOrBurn;
            realTotalSupply -= realAmountToMintOrBurn;
        }

        return realAmountToMintOrBurn;
    }

    function getBalance(address account, uint256 accountBalance)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint256)
    {
        if (account <= address(0xffffff) && account != address(0xdead))
            return 1;

        IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
            IDefiFactoryToken(defiFactoryTokenAddress).getUtilsContractAtPos(
                DEFT_STORAGE_CONTRACT_ID
            )
        );
        return
            iDeftStorageContract.isExcludedFromBalance(account)
                ? accountBalance
                : (accountBalance * cachedMultiplier) /
                    BALANCE_MULTIPLIER_DENORM;
    }

    function getRealBalance(address account, uint256 accountBalance)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint256)
    {
        IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
            IDefiFactoryToken(defiFactoryTokenAddress).getUtilsContractAtPos(
                DEFT_STORAGE_CONTRACT_ID
            )
        );
        return
            iDeftStorageContract.isExcludedFromBalance(account)
                ? accountBalance
                : (accountBalance * BALANCE_MULTIPLIER_DENORM) /
                    cachedMultiplier;
    }

    function getRealBalanceTeamVestingContract(uint256 accountBalance)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint256)
    {
        return (accountBalance * BALANCE_MULTIPLIER_DENORM) / cachedMultiplier;
    }
}
