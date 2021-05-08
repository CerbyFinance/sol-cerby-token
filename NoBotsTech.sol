// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./INoBotsTech.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";


contract NoBotsTech is AccessControlEnumerable {
    bytes32 public constant ROLE_PARENT = keccak256("ROLE_PARENT");
    bytes32 public constant ROLE_WHITELIST = keccak256("ROLE_WHITELIST");
    bytes32 public constant ROLE_CUSTOM_TAX = keccak256("ROLE_CUSTOM_TAX");
    bytes32 public constant ROLE_EXCLUDE_FROM_BALANCE = keccak256("ROLE_EXCLUDE_FROM_BALANCE");
    
    uint constant BALANCE_MULTIPLIER_DENORM = 1e18;
    uint public cachedMultiplier = BALANCE_MULTIPLIER_DENORM;
    
    // TODO: add option to extract all data for migration
    
    
    mapping (address => uint) public temporaryReferralRealAmounts;
    mapping (address => uint) public referrerRealBalances;
    mapping (address => address) public referralToReferrer;
    
    mapping (address => uint) public customTaxPercents;
    
    uint public batchBurnAndReward;
    uint public lastCachedTimestamp = block.timestamp;
    uint public secondsBetweenUpdates;
    
    uint public humanTaxPercent = 1e5; // 10.0%
    uint public botTaxPercent = 99e4; // 99.0%
    uint public refTaxPercent = 5e3; // 5.0%
    uint public firstLevelRefPercent = 1e3; // 1.0%
    uint public secondLevelRefPercent = 250; // 0.25%
    uint constant TAX_PERCENT_DENORM = 1e6;
    
    address constant BURN_ADDRESS = address(0x0);
    
    uint public rewardsBalance;
    uint public realTotalSupply;
    
    struct LastBlock {
        uint received;
        uint sent;
    }
    mapping(address => LastBlock) lastBlock;
    uint public howManyBlocksAgoReceived = 0;
    uint public howManyBlocksAgoSent = 0;
    
    struct RoleAccess {
        bytes32 role;
        address addr;
    }
    
    event MultiplierUpdated(uint newMultiplier);
    event BotTransactionDetected(address from, address to, uint transferAmount, uint taxedAmount);
    event ReferralRewardUpdated(address referral, uint amount);
    event ReferralRegistered(address referral, address referrer);
    event ReferralDeleted(address referral, address referrer);
    
    
    constructor () {
        _setupRole(ROLE_ADMIN, _msgSender());
    }
    
    modifier onlyAdmins {
        require(hasRole(ROLE_ADMIN, _msgSender()), "NoBotsTech: !ROLE_ADMIN");
        _;
    }
    
    modifier onlyParentContractOrAdmins {
        require(            
            hasRole(ROLE_PARENT, _msgSender()) || 
            hasRole(ROLE_ADMIN, _msgSender()), 
            "NoBotsTech: !ROLE_PARENT_OR_ADMIN"
        );
        _;
    }
    
    function updateHowManyBlocksAgo(uint _howManyBlocksAgoReceived, uint _howManyBlocksAgoSent)
        external
        onlyAdmins
    {
        howManyBlocksAgoReceived = _howManyBlocksAgoReceived;
        howManyBlocksAgoSent = _howManyBlocksAgoSent;
    }
    
    function grantRolesBulk(RoleAccess[] calldata roles)
        external
        onlyAdmins
    {
        for(uint i = 0; i<roles.length; i++)
        {
            _setupRole(roles[i].role, roles[i].addr);
        }
    }
    
    function getCalculatedReferrerRewards(address referrer, address[] calldata referrals)
        external
        onlyParentContractOrAdmins
        view
        returns (uint)
    {
        uint referrerRealBalance = referrerRealBalances[referrer];
        
        address temporaryReferrer;
        for (uint i = 0; i < referrals.length; i++)
        {
            if (temporaryReferralRealAmounts[referrals[i]] == 0) continue;
            
            temporaryReferrer = referralToReferrer[referrals[i]]; // Finding first-level referrer on top of current referrals[i]
            if (temporaryReferrer != BURN_ADDRESS)
            {
                if (temporaryReferrer == referrer)
                {
                    referrerRealBalance += 
                        (temporaryReferralRealAmounts[referrals[i]] * firstLevelRefPercent) / TAX_PERCENT_DENORM; // 1.00%
                }
                
                temporaryReferrer = referralToReferrer[temporaryReferrer]; // Finding second-level referrer on top of first-level referrer
                if (temporaryReferrer != BURN_ADDRESS)
                {
                    if (temporaryReferrer == referrer)
                    {
                        referrerRealBalance += 
                            (temporaryReferralRealAmounts[referrals[i]] * secondLevelRefPercent) / TAX_PERCENT_DENORM; // 0.25%
                    }
                }
            }
        }
        
        return (referrerRealBalance * cachedMultiplier) / BALANCE_MULTIPLIER_DENORM;
    }
    
    function updateReferrersRewards(address[] calldata referrals)
        external
        onlyParentContractOrAdmins
    {
        address temporaryReferrer;
        for (uint i = 0; i < referrals.length; i++)
        {
            if (temporaryReferralRealAmounts[referrals[i]] == 0) continue;
            
            temporaryReferrer = referralToReferrer[referrals[i]]; // Finding first-level referrer on top of current referrals[i]
            if (temporaryReferrer != BURN_ADDRESS)
            {
                referrerRealBalances[temporaryReferrer] += 
                    (temporaryReferralRealAmounts[referrals[i]] * firstLevelRefPercent) / TAX_PERCENT_DENORM; // 1.00%
                emit ReferralRewardUpdated(temporaryReferrer, referrerRealBalances[temporaryReferrer]);
                
                temporaryReferrer = referralToReferrer[temporaryReferrer]; // Finding second-level referrer on top of first-level referrer
                if (temporaryReferrer != BURN_ADDRESS)
                {
                    referrerRealBalances[temporaryReferrer] += 
                        (temporaryReferralRealAmounts[referrals[i]] * secondLevelRefPercent) / TAX_PERCENT_DENORM; // 0.25%
                    emit ReferralRewardUpdated(temporaryReferrer, referrerRealBalances[temporaryReferrer]);
                }
                
                temporaryReferralRealAmounts[referrals[i]] = 0;
            }
        }
    }
    
    function getTemporaryReferralRealAmountsBulk(address[] calldata addrs)
        external
        onlyParentContractOrAdmins
        view
        returns (TemporaryReferralRealAmountsBulk[] memory)
    {
        TemporaryReferralRealAmountsBulk[] memory output = new TemporaryReferralRealAmountsBulk[](addrs.length);
        for(uint i = 0; i<addrs.length; i++)
        {
            output[i] = TemporaryReferralRealAmountsBulk(
                addrs[i],
                temporaryReferralRealAmounts[addrs[i]]
            );
        }
        
        return output;
    }
    
    function filterNonZeroReferrals(address[] calldata referrals)
        external
        onlyParentContractOrAdmins
        view
        returns (address[] memory)
    {
        address[] memory output = referrals;
        for(uint i = 0; i < referrals.length; i++)
        {
            if (temporaryReferralRealAmounts[referrals[i]] == 0)
            {
                output[i] = BURN_ADDRESS;
            }
        }
        
        return output;
    }
    
    function getCachedReferrerRewards(address referrer)
        external
        onlyParentContractOrAdmins
        view
        returns (uint)
    {
        return (referrerRealBalances[referrer] * cachedMultiplier) / BALANCE_MULTIPLIER_DENORM;
    }
    
    function clearReferrerRewards(address addr)
        external
        onlyParentContractOrAdmins
    {
        referrerRealBalances[addr] = 0;
    }
    
    function registerReferral(address referral, address referrer)
        external
        onlyParentContractOrAdmins
    {
        require(referrer != BURN_ADDRESS && referral != BURN_ADDRESS, "NoBotsTech: !burn");
        require(referrer != referral, "NoBotsTech: !self_ref");
        require(isNotContract(referral) && isNotContract(referrer), "NoBotsTech: !contract");
        
        if (referralToReferrer[referral] != BURN_ADDRESS) // referrer exists
        {
            emit ReferralDeleted(referral, referralToReferrer[referral]);
        }
        
        referralToReferrer[referral] = referrer;
        emit ReferralRegistered(referral, referrer);
    }
    
    function updateReCachePeriod(uint _secondsBetweenUpdates)
        external
        onlyAdmins
    {
        secondsBetweenUpdates = _secondsBetweenUpdates;
    }
    
    function updateCustomTaxForAddress(address addr, uint newCustomTaxPercent)
        external
        onlyAdmins
    {
        customTaxPercents[addr] = newCustomTaxPercent;
        _setupRole(ROLE_CUSTOM_TAX, addr);
    }

    function updateTaxPercent(
        uint _refTaxPercent,
        uint _botTaxPercent,
        uint _humanTaxPercent,
        uint _firstLevelRefPercent,
        uint _secondLevelRefPercent
    )
        external
        onlyAdmins
    {
        refTaxPercent = _refTaxPercent;
        botTaxPercent = _botTaxPercent;
        humanTaxPercent = _humanTaxPercent;
        firstLevelRefPercent = _firstLevelRefPercent;
        secondLevelRefPercent = _secondLevelRefPercent;
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
        onlyParentContractOrAdmins
        view
        returns (uint)
    {
        return realTotalSupply + rewardsBalance;
    }
    
    function getRewardsBalance()
        external
        view
        onlyParentContractOrAdmins
        returns (uint)
    {
        return rewardsBalance;
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
    
    function delayedUpdateCacheMultiplier()
        private
    {   
        if (block.timestamp > lastCachedTimestamp + secondsBetweenUpdates)
        {
            forcedUpdateCacheMultiplier();
        }
    }
    
    function chargeCustomTax(uint taxAmount, uint accountBalance)
        external
        onlyParentContractOrAdmins
        returns(uint)
    {
        uint realTaxAmount = 
            (taxAmount * BALANCE_MULTIPLIER_DENORM) / cachedMultiplier;
        require(accountBalance >= realTaxAmount, "NoBotsTech: !accountBalance");
        
        batchBurnAndReward += realTaxAmount;
        accountBalance -= realTaxAmount;
        
        delayedUpdateCacheMultiplier();
        
        return accountBalance;
    }
 
    function prepareTaxAmounts(
        TaxAmountsInput calldata taxAmountsInput
    ) 
        external
        onlyParentContractOrAdmins
        returns(TaxAmountsOutput memory taxAmountsOutput)
    {
        uint realTransferAmount = 
            (taxAmountsInput.transferAmount * BALANCE_MULTIPLIER_DENORM) / cachedMultiplier;
        
        require(
            taxAmountsInput.senderBalance >= realTransferAmount,
            "NoBotsTech: !balance"
        );
        require(
            realTransferAmount > 1,
            "NoBotsTech: !amount"
        );
        
        uint burnAndRewardRealAmount;
        if (referralToReferrer[taxAmountsInput.sender] != BURN_ADDRESS) // If sender is referral under referralToReferrer[taxAmountsInput.sender] referrer
        {
            burnAndRewardRealAmount = (realTransferAmount * refTaxPercent) / TAX_PERCENT_DENORM;
            
            temporaryReferralRealAmounts[taxAmountsInput.sender] += realTransferAmount;
        } else if ( // For example for binance wallet I can set custom tax = 0%
            hasRole(ROLE_CUSTOM_TAX, taxAmountsInput.sender) ||
            hasRole(ROLE_CUSTOM_TAX, taxAmountsInput.recipient)
        ) {
            // Getting minimum tax of sender or recipient
            uint customTax = customTaxPercents[taxAmountsInput.sender] < customTaxPercents[taxAmountsInput.recipient]?
                customTaxPercents[taxAmountsInput.sender]: customTaxPercents[taxAmountsInput.recipient];
            burnAndRewardRealAmount = (realTransferAmount * customTax) / TAX_PERCENT_DENORM;
        } else if (
            /*
                isBot = !hasRole(ROLE_WHITELIST, taxAmountsInput.sender) &&
                            (lastBlock[taxAmountsInput.sender].received + howManyBlocksAgoReceived > block.number 
                                || isContract(sender)) || 
                        !hasRole(ROLE_WHITELIST, taxAmountsInput.recipient) &&
                            (lastBlock[taxAmountsInput.recipient].sent + howManyBlocksAgoSent > block.number 
                                || isContract(recipient))
                isBot      = (!A && (B || C)) || (!D && (E || F))
                isHuman = !isBot = (A || (!B && !C)) && (D || (!E && !F))
            */
            
            // isHuman condition below
            (hasRole(ROLE_WHITELIST, taxAmountsInput.sender) || 
                (lastBlock[taxAmountsInput.sender].received + howManyBlocksAgoReceived < block.number && 
                    isNotContract(taxAmountsInput.sender))) &&
                
            (hasRole(ROLE_WHITELIST, taxAmountsInput.recipient) || 
                (lastBlock[taxAmountsInput.recipient].sent + howManyBlocksAgoSent < block.number && 
                    isNotContract(taxAmountsInput.recipient)))
        ) {
            burnAndRewardRealAmount = (realTransferAmount * humanTaxPercent) / TAX_PERCENT_DENORM;
        } else // isBot
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
        
        uint recipientGetsRealAmount = realTransferAmount - burnAndRewardRealAmount;
        taxAmountsOutput.burnAndRewardAmount = 
            (burnAndRewardRealAmount * cachedMultiplier) / BALANCE_MULTIPLIER_DENORM; // Actual amount we burned and have to show in event
        taxAmountsOutput.recipientGetsAmount = 
            taxAmountsInput.transferAmount - taxAmountsOutput.burnAndRewardAmount; // Actual amount recipient got and have to show in event
        
        // Saving when sender or recipient made last transaction for anti bot system
        lastBlock[taxAmountsInput.recipient].received = block.number;
        lastBlock[taxAmountsInput.sender].sent = block.number;
        
        taxAmountsOutput.senderBalance = taxAmountsInput.senderBalance - realTransferAmount;
        taxAmountsOutput.recipientBalance = taxAmountsInput.recipientBalance + recipientGetsRealAmount;
        batchBurnAndReward += burnAndRewardRealAmount;        
        
        delayedUpdateCacheMultiplier();
        
        return (taxAmountsOutput);
    }
    
    function prepareHumanAddressMintOrBurnRewardsAmounts(bool isMint, address account, uint desiredAmountToMintOrBurn)
        external
        onlyParentContractOrAdmins
        returns (uint)
    {
        require(
            hasRole(ROLE_WHITELIST, account) || 
            isNotContract(account), 
            "NoBotsTech: !human"
        );
        
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
        onlyParentContractOrAdmins
        view
        returns(uint)
    {
        return hasRole(ROLE_EXCLUDE_FROM_BALANCE, account)? accountBalance:
            (accountBalance * cachedMultiplier) / BALANCE_MULTIPLIER_DENORM;
    }
    
    function getRealBalanceTeamVestingContract(uint accountBalance)
        external
        onlyParentContractOrAdmins
        view
        returns(uint)
    {
        return (accountBalance * BALANCE_MULTIPLIER_DENORM) / cachedMultiplier;
    }
    
    function getRealBalance(address account, uint accountBalance)
        external
        onlyParentContractOrAdmins
        view
        returns(uint)
    {
        return hasRole(ROLE_EXCLUDE_FROM_BALANCE, account)? accountBalance:
            (accountBalance * BALANCE_MULTIPLIER_DENORM) / cachedMultiplier;
    }
}