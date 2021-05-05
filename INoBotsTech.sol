// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

struct TaxAmountsInput {
    address sender;
    address recipient;
    uint transferAmount;
    uint senderBalance;
    uint recipientBalance;
}
struct TaxAmountsOutput {
    uint senderBalance;
    uint recipientBalance;
    uint burnAndRewardAmount;
    uint recipientGetsAmount;
}

interface INoBotsTech {
    function prepareTaxAmounts(
        TaxAmountsInput calldata taxAmountsInput
    ) 
        external
        returns(TaxAmountsOutput memory taxAmountsOutput);
        
    function prepareHumanAddressMintOrBurnRewardsAmounts(bool isMint, address account, uint desiredAmountToMintOrBurn)
        external
        returns (uint realAmountToMintOrBurn);
        
    function prepareUniswapMintOrBurnRewardsAmounts(bool isMint, address account, uint realAmountToMintOrBurn)
        external;
        
    function getBalance(address account, uint accountBalance)
        external
        view
        returns(uint);
        
    function getRealBalance(address account, uint accountBalance)
        external
        view
        returns(uint);
        
    function getRealBalanceVestingContract(uint accountBalance)
        external
        view
        returns(uint);
        
    function getTotalSupply()
        external
        view
        returns (uint);
        
    function grantRole(bytes32 role, address account) 
        external;
        
    function getCalculatedReferrerRewards(address addr, address[] calldata referrals)
        external
        view
        returns (uint);
        
    function getCachedReferrerRewards(address addr)
        external
        view
        returns (uint);
    
    function updateReferrersRewards(address[] calldata referrals)
        external;
    
    function clearReferrerRewards(address addr)
        external;
    
    function chargeCustomTax(uint taxAmount, uint accountBalance)
        external
        returns (uint);
    
    function chargeCustomTaxPreBurned(uint taxAmount)
        external;
        
    function registerReferral(address referral, address referrer)
        external;
        
    function filterNonZeroReferrals(address[] calldata referrals)
        external
        view
        returns (address[] memory);
    
    event MultiplierUpdated(uint newMultiplier);
    event BotTransactionDetected(address from, address to, uint amount);
    event ReferralRewardUpdated(address referral, uint amount);
    event ReferralRegistered(address referral, address referrer);
    event ReferralDeleted(address referral, address referrer);
}