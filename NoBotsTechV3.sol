// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.8;

import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/INoBotsTech.sol";
import "./interfaces/IWeth.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IDeftStorageContract.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";



contract NoBotsTechV3 is AccessControlEnumerable {
    
    uint constant DEFT_STORAGE_CONTRACT_ID = 3;
    //uint constant UNISWAP_V2_PAIR_ADDRESS_ID = 4;
    
    
    
    address defiFactoryTokenAddress = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840;
    
    uint botTaxPercent = 999e3; // 99.9%
    uint constant TAX_PERCENT_DENORM = 1e6;
    
    
    address constant BURN_ADDRESS = address(0x0);
    
    uint realTotalSupply;
    
    
    
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
        { // isBuy or isTransfer
            uint newBuyTimestamp = block.timestamp;
            
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
    
    
    function prepareHumanAddressMintOrBurnRewardsAmounts(bool isMint, address account, uint desiredAmountToMintOrBurn)
        external
        onlyRole(ROLE_ADMIN)
        returns (uint)
    {
        if (isMint) 
        {
            realTotalSupply += desiredAmountToMintOrBurn;
            
            uint newBuyTimestampAccount = block.timestamp;
            
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