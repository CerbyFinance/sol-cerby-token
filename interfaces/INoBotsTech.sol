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
struct TemporaryReferralRealAmountsBulk {
    address addr;
    uint realBalance;
}

interface INoBotsTech {
    function prepareTaxAmounts(
        TaxAmountsInput calldata taxAmountsInput
    ) 
        external
        returns(TaxAmountsOutput memory taxAmountsOutput);
    
    function getTemporaryReferralRealAmountsBulk(address[] calldata addrs)
        external
        view
        returns (TemporaryReferralRealAmountsBulk[] memory);
        
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
        
    function getRealBalanceTeamVestingContract(uint accountBalance)
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
        
    function fillTestReferralTemporaryBalances(address[] calldata referrals)
        external;
    
    event MultiplierUpdated(uint newMultiplier);
    event BotTransactionDetected(address from, address to, uint transferAmount, uint taxedAmount);
    event ReferrerRewardUpdated(address referrer, uint amount);
    event ReferralRegistered(address referral, address referrer);
    event ReferrerReplaced(address referral, address referrerFrom, address referrerTo);
}