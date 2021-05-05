// SPDX-License-Identifier: MIT

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
    
    mapping (address => uint) public temporaryReferralAmounts;
    mapping (address => uint) public referrerBalances;
    mapping (address => address) public referralToReferrer;
    
    mapping (address => uint) public customTaxPercents;
    
    uint public batchBurnAndReward;
    uint lastCachedTimestamp = block.timestamp;
    uint secondsBetweenUpdates;
    
    uint public humanTaxPercent = 1e5; // 10.0%
    uint public botTaxPercent = 99e4; // 99.0%
    uint public refTaxPercent = 5e3; // 5.0%
    uint public firstLevelRefPercent = 1e3; // 1.0%
    uint public secondLevelRefPercent = 250; // 0.25%
    uint constant TAX_PERCENT_DENORM = 1e6;
    
    address constant BURN_ADDRESS = address(0x0);
    
    uint rewardsBalance;
    uint totalSupply;
    
    struct LastBlock {
        uint received;
        uint sent;
    }
    mapping(address => LastBlock) lastBlock;
    
    struct RoleAccess {
        bytes32 role;
        address addr;
    }
    
    event MultiplierUpdated(uint newMultiplier);
    event BotTransactionDetected(address from, address to, uint amount);
    event ReferralRewardUpdated(address referral, uint amount);
    event ReferralRegistered(address referral, address referrer);
    event ReferralDeleted(address referral, address referrer);
    
    
    constructor () {
        _setupRole(ROLE_ADMIN, _msgSender());
        
        /*
            "0x539FaA851D86781009EC30dF437D794bCd090c8F", [
                    "0x8323bf1837567d0c5af5bF72E9001cDB6220e7D7"
                ]
        */
        registerReferral(0xDc15Ca882F975c33D8f20AB3669D27195B8D87a6, 0xE019B37896f129354cf0b8f1Cf33936b86913A34);
        registerReferral(0xE019B37896f129354cf0b8f1Cf33936b86913A34, 0xDc15Ca882F975c33D8f20AB3669D27195B8D87a6);
        registerReferral(0x8323bf1837567d0c5af5bF72E9001cDB6220e7D7, 0x539FaA851D86781009EC30dF437D794bCd090c8F);
    }
    
    modifier onlyAdmins {
        require(hasRole(ROLE_ADMIN, _msgSender()), "NoBotsTech: !ROLE_ADMIN");
        _;
    }
    
    modifier onlyParentContractOrAdmins {
        
        
        require(
            // TODO: remove true on production!!!!!!!!!!!!!!!!!!!!!!!
            
            hasRole(ROLE_PARENT, _msgSender()) || 
            hasRole(ROLE_ADMIN, _msgSender()), 
            "NoBotsTech: !ROLE_PARENT"
        );
        _;
    }
    
    function grantRolesBulk(RoleAccess[] calldata roles)
        public
        onlyAdmins
    {
        for(uint i = 0; i<roles.length; i++)
        {
            _setupRole(roles[i].role, roles[i].addr);
        }
    }
    
    function getCalculatedReferrerRewards(address referrer, address[] calldata referrals)
        public
        onlyParentContractOrAdmins
        view
        returns (uint)
    {
        uint referrerBalance = referrerBalances[referrer];
        
        address temporaryReferrer;
        for (uint i = 0; i < referrals.length; i++)
        {
            if (temporaryReferralAmounts[referrals[i]] == 0) continue;
            
            temporaryReferrer = referralToReferrer[referrals[i]];
            if (temporaryReferrer != BURN_ADDRESS)
            {
                if (temporaryReferrer == referrer)
                {
                    referrerBalance += 
                        (temporaryReferralAmounts[referrals[i]] * firstLevelRefPercent) / TAX_PERCENT_DENORM; // 0.25%
                }
                
                temporaryReferrer = referralToReferrer[temporaryReferrer]; // ref lvl2
                if (temporaryReferrer != BURN_ADDRESS)
                {
                    if (temporaryReferrer == referrer)
                    {
                        referrerBalance += 
                            (temporaryReferralAmounts[referrals[i]] * secondLevelRefPercent) / TAX_PERCENT_DENORM; // 1.00%
                    }
                }
            }
        }
        
        return (referrerBalance * cachedMultiplier) / BALANCE_MULTIPLIER_DENORM;
    }
    
    function updateReferrersRewards(address[] calldata referrals)
        onlyParentContractOrAdmins
        public
    {
        address temporaryReferrer;
        for (uint i = 0; i < referrals.length; i++) // ref lvl1
        {
            if (temporaryReferralAmounts[referrals[i]] == 0) continue;
            
            referrerBalances[temporaryReferrer] += 
                (temporaryReferralAmounts[referrals[i]] * firstLevelRefPercent) / TAX_PERCENT_DENORM; // 1.00%
            emit ReferralRewardUpdated(temporaryReferrer, referrerBalances[temporaryReferrer]);
            
            temporaryReferrer = referralToReferrer[temporaryReferrer]; // ref lvl2
            if (temporaryReferrer != BURN_ADDRESS)
            {
                referrerBalances[temporaryReferrer] += 
                    (temporaryReferralAmounts[referrals[i]] * secondLevelRefPercent) / TAX_PERCENT_DENORM; // 0.25%
                emit ReferralRewardUpdated(temporaryReferrer, referrerBalances[temporaryReferrer]);
            }
            
            temporaryReferralAmounts[referrals[i]] = 0;
        }
    }
    
    // TODO: get temporary referrer balances bulk
    
    function filterNonZeroReferrals(address[] calldata referrals)
        onlyParentContractOrAdmins
        public
        view
        returns (address[] memory)
    {
        address[] memory output = referrals;
        for(uint i = 0; i < referrals.length; i++)
        {
            if (temporaryReferralAmounts[referrals[i]] == 0)
            {
                output[i] = BURN_ADDRESS;
            }
        }
        
        return output;
    }
    
    function getCachedReferrerRewards(address referrer)
        public
        onlyParentContractOrAdmins
        view
        returns (uint)
    {
        return (referrerBalances[referrer] * cachedMultiplier) / BALANCE_MULTIPLIER_DENORM;
    }
    
    function clearReferrerRewards(address addr)
        public
        onlyParentContractOrAdmins
    {
        referrerBalances[addr] = 0;
    }
    
    function registerReferral(address referral, address referrer)
        public
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
    
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
    
    function isNotContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size == 0;
    }
    
    function getTotalSupply()
        public
        view
        onlyParentContractOrAdmins
        returns (uint)
    {
        return totalSupply + rewardsBalance;
    }
    
    function getRewardsBalance()
        public
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
    
        totalSupply -= batchBurnAndReward;
        rewardsBalance += batchBurnAndReward/2;
        batchBurnAndReward = 0;
        
        cachedMultiplier = BALANCE_MULTIPLIER_DENORM + 
            (BALANCE_MULTIPLIER_DENORM * rewardsBalance) / totalSupply;
            
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
        public
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
    
    function chargeCustomTaxPreBurned(uint taxAmount)
        public
        onlyParentContractOrAdmins
    {
        uint realTaxAmount = 
            (taxAmount * BALANCE_MULTIPLIER_DENORM) / cachedMultiplier;
        
        batchBurnAndReward += realTaxAmount;
        totalSupply += realTaxAmount; // because we substracted while burning and substracting again in delayedUpdateCacheMultiplier
        
        delayedUpdateCacheMultiplier();
    }
 
    function prepareTaxAmounts(
        TaxAmountsInput calldata taxAmountsInput
    ) 
        external
        onlyParentContractOrAdmins
        returns(TaxAmountsOutput memory taxAmountsOutput)
    {
        require(
            taxAmountsInput.sender != taxAmountsInput.recipient,
            "NoBotsTech: !self"
        );
        
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
        if (referralToReferrer[taxAmountsInput.sender] != BURN_ADDRESS)
        {
            burnAndRewardRealAmount = (realTransferAmount * refTaxPercent) / TAX_PERCENT_DENORM;
            
            temporaryReferralAmounts[taxAmountsInput.sender] += realTransferAmount;
        } else if (
            hasRole(ROLE_CUSTOM_TAX, taxAmountsInput.sender) ||
            hasRole(ROLE_CUSTOM_TAX, taxAmountsInput.recipient)
        ) {
            uint customTax = customTaxPercents[taxAmountsInput.sender] < customTaxPercents[taxAmountsInput.recipient]?
                customTaxPercents[taxAmountsInput.sender]: customTaxPercents[taxAmountsInput.recipient];
            burnAndRewardRealAmount = (realTransferAmount * customTax) / TAX_PERCENT_DENORM;
        } else if (
            /*
                isBot = !whitelistContracts[sender].isWhitelisted &&
                            (lastBlock[sender].received == block.number || isContract(sender)) || 
                        !whitelistContracts[recipient].isWhitelisted &&
                            (lastBlock[recipient].sent == block.number || isContract(recipient))
                isBot      = (!A && (B || C)) || (!D && (E || F))
                isHuman = !isBot = (A || (!B && !C)) && (D || (!E && !F))
            */
            
            
            (hasRole(ROLE_WHITELIST, taxAmountsInput.sender) || 
                (lastBlock[taxAmountsInput.sender].received != block.number && isNotContract(taxAmountsInput.sender))) &&
                
            (hasRole(ROLE_WHITELIST, taxAmountsInput.recipient) || 
                (lastBlock[taxAmountsInput.recipient].sent != block.number && isNotContract(taxAmountsInput.recipient)))
        ) {
            burnAndRewardRealAmount = (realTransferAmount * humanTaxPercent) / TAX_PERCENT_DENORM;
        } else
        {
            burnAndRewardRealAmount = (realTransferAmount * botTaxPercent) / TAX_PERCENT_DENORM;
            
            emit BotTransactionDetected(
                taxAmountsInput.sender, 
                taxAmountsInput.recipient, 
                taxAmountsInput.transferAmount
            );
        }
        
        uint recipientGetsRealAmount = realTransferAmount - burnAndRewardRealAmount;
        taxAmountsOutput.burnAndRewardAmount = 
            (burnAndRewardRealAmount * cachedMultiplier) / BALANCE_MULTIPLIER_DENORM;
        taxAmountsOutput.recipientGetsAmount = 
            taxAmountsInput.transferAmount - taxAmountsOutput.burnAndRewardAmount;
        
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
        returns (uint realAmountToMintOrBurn)
    {
        require(hasRole(ROLE_WHITELIST, account) || isNotContract(account), "NoBotsTech: !human");
        
        realAmountToMintOrBurn = (BALANCE_MULTIPLIER_DENORM * desiredAmountToMintOrBurn) / cachedMultiplier;
        uint realRewardToMintOrBurn = desiredAmountToMintOrBurn - realAmountToMintOrBurn;
        if (isMint) 
        {
            rewardsBalance += realRewardToMintOrBurn;
            totalSupply += realAmountToMintOrBurn;
        } else
        {
            rewardsBalance -= realRewardToMintOrBurn;
            totalSupply -= realAmountToMintOrBurn;
        }
        
        forcedUpdateCacheMultiplier();
        
        return realAmountToMintOrBurn;
    }
    
    function getBalance(address account, uint accountBalance)
        external
        view
        onlyParentContractOrAdmins
        returns(uint)
    {
        return hasRole(ROLE_EXCLUDE_FROM_BALANCE, account)? accountBalance:
            (accountBalance * cachedMultiplier) / BALANCE_MULTIPLIER_DENORM;
    }
    
    function getRealBalanceVestingContract(uint accountBalance)
        external
        view
        onlyParentContractOrAdmins
        returns(uint)
    {
        return (accountBalance * BALANCE_MULTIPLIER_DENORM) / cachedMultiplier;
    }
    
    function getRealBalance(address account, uint accountBalance)
        external
        view
        onlyParentContractOrAdmins
        returns(uint)
    {
        return hasRole(ROLE_EXCLUDE_FROM_BALANCE, account)? accountBalance:
            (accountBalance * BALANCE_MULTIPLIER_DENORM) / cachedMultiplier;
    }
}