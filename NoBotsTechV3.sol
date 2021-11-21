// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.8;

import "./interfaces/ICerbyBotDetection.sol";
import "./interfaces/IWeth.sol";
import "./interfaces/IDefiFactoryToken.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";


struct TaxAmountsInput {
    address sender;
    address recipient;
    uint transferAmount;
    uint senderRealBalance;
    uint recipientRealBalance;
}
struct TaxAmountsOutput {
    uint senderRealBalance;
    uint recipientRealBalance;
    uint burnAndRewardAmount;
    uint recipientGetsAmount;
}


contract NoBotsTechV3 is AccessControlEnumerable {
    
    uint constant CERBY_BOT_DETECTION_CONTRACT_ID = 3;
    
    address defiFactoryTokenAddress = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840;
    
    address constant BURN_ADDRESS = address(0x0);
    
    uint realTotalSupply;
    
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
        
        ICerbyBotDetection iCerbyBotDetection = ICerbyBotDetection(
            ICerbyToken(defiFactoryTokenAddress).getUtilsContractAtPos(CERBY_BOT_DETECTION_CONTRACT_ID)
        );
        iCerbyBotDetection.checkTransactionInfo(defiFactoryTokenAddress, taxAmountsInput.sender, taxAmountsInput.recipient);
        
        taxAmountsOutput.senderRealBalance = taxAmountsInput.senderRealBalance - taxAmountsInput.transferAmount;
        taxAmountsOutput.recipientRealBalance = taxAmountsInput.recipientRealBalance + taxAmountsInput.transferAmount;
        
        //taxAmountsOutput.burnAndRewardAmount = 0; // Actual amount we burned and have to show in event
        taxAmountsOutput.recipientGetsAmount = taxAmountsInput.transferAmount; // Actual amount recipient got and have to show in event
        
        return taxAmountsOutput;
    }
    
    
    function prepareHumanAddressMintOrBurnRewardsAmounts(bool isMint, address, uint desiredAmountToMintOrBurn)
        external
        onlyRole(ROLE_ADMIN)
        returns (uint)
    {
        if (isMint) 
        {
            realTotalSupply += desiredAmountToMintOrBurn;
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