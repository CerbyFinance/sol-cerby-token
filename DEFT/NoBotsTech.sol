// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.4;

import "../interfaces/INoBotsTech.sol";
import "../openzeppelin/access/AccessControlEnumerable.sol";

contract NoBotsTech is AccessControlEnumerable {
    bytes32 public constant ROLE_WHITELIST = keccak256("ROLE_WHITELIST");
    bytes32 public constant ROLE_CUSTOM_TAX = keccak256("ROLE_CUSTOM_TAX");
    bytes32 public constant ROLE_EXCLUDE_FROM_BALANCE =
        keccak256("ROLE_EXCLUDE_FROM_BALANCE");

    uint256 constant BALANCE_MULTIPLIER_DENORM = 1e18;
    uint256 public cachedMultiplier = BALANCE_MULTIPLIER_DENORM;

    mapping(address => uint256) public temporaryReferralRealAmounts;
    mapping(address => uint256) public referrerRealBalances;
    mapping(address => address) public referralToReferrer;

    mapping(address => uint256) public customTaxPercents;

    uint256 public batchBurnAndReward;
    uint256 public lastCachedTimestamp = block.timestamp;
    uint256 public secondsBetweenUpdates = 60;

    uint256 public humanTaxPercent = 1e5; // 10.0%
    uint256 public botTaxPercent = 99e4; // 99.0%
    uint256 public refTaxPercent = 5e4; // 5.0%
    uint256 public firstLevelRefPercent = 1e4; // 1.0%
    uint256 public secondLevelRefPercent = 2500; // 0.25%
    uint256 constant TAX_PERCENT_DENORM = 1e6;

    address constant BURN_ADDRESS = address(0x0);

    uint256 public rewardsBalance;
    uint256 public realTotalSupply;

    struct SentOrReceivedAtBlockStorage {
        uint256 receivedAtBlock;
        uint256 sentAtBlock;
    }
    mapping(address => SentOrReceivedAtBlockStorage) sentOrReceivedAtBlockStorage;
    uint256 public howManyBlocksAgoReceived = 0;
    uint256 public howManyBlocksAgoSent = 0;

    struct RoleAccess {
        bytes32 role;
        address addr;
    }

    event MultiplierUpdated(uint256 newMultiplier);
    event BotTransactionDetected(
        address from,
        address to,
        uint256 transferAmount,
        uint256 taxedAmount
    );
    event ReferrerRewardUpdated(address referrer, uint256 amount);
    event ReferralRegistered(address referral, address referrer);
    event ReferrerReplaced(
        address referral,
        address referrerFrom,
        address referrerTo
    );

    constructor() {
        _setupRole(ROLE_ADMIN, _msgSender());

        emit MultiplierUpdated(cachedMultiplier);
    }

    function updateHowManyBlocksAgo(
        uint256 _howManyBlocksAgoReceived,
        uint256 _howManyBlocksAgoSent
    ) external onlyRole(ROLE_ADMIN) {
        howManyBlocksAgoReceived = _howManyBlocksAgoReceived;
        howManyBlocksAgoSent = _howManyBlocksAgoSent;
    }

    function grantRolesBulk(RoleAccess[] calldata roles)
        external
        onlyRole(ROLE_ADMIN)
    {
        for (uint256 i = 0; i < roles.length; i++) {
            _setupRole(roles[i].role, roles[i].addr);
        }
    }

    function getCalculatedReferrerRewards(
        address referrer,
        address[] calldata referrals
    ) external view onlyRole(ROLE_ADMIN) returns (uint256) {
        uint256 referrerRealBalance = referrerRealBalances[referrer];

        address temporaryReferrer;
        for (uint256 i = 0; i < referrals.length; i++) {
            if (temporaryReferralRealAmounts[referrals[i]] == 0) continue;

            temporaryReferrer = referralToReferrer[referrals[i]]; // Finding first-level referrer on top of current referrals[i]
            if (temporaryReferrer != BURN_ADDRESS) {
                if (temporaryReferrer == referrer) {
                    referrerRealBalance +=
                        (temporaryReferralRealAmounts[referrals[i]] *
                            firstLevelRefPercent) /
                        TAX_PERCENT_DENORM; // 1.00%
                }

                temporaryReferrer = referralToReferrer[temporaryReferrer]; // Finding second-level referrer on top of first-level referrer
                if (temporaryReferrer != BURN_ADDRESS) {
                    if (temporaryReferrer == referrer) {
                        referrerRealBalance +=
                            (temporaryReferralRealAmounts[referrals[i]] *
                                secondLevelRefPercent) /
                            TAX_PERCENT_DENORM; // 0.25%
                    }
                }
            }
        }

        return
            (referrerRealBalance * cachedMultiplier) /
            BALANCE_MULTIPLIER_DENORM;
    }

    function updateReferrersRewards(address[] calldata referrals)
        external
        onlyRole(ROLE_ADMIN)
    {
        address temporaryReferrer;
        for (uint256 i = 0; i < referrals.length; i++) {
            if (temporaryReferralRealAmounts[referrals[i]] == 0) continue;

            temporaryReferrer = referralToReferrer[referrals[i]]; // Finding first-level referrer on top of current referrals[i]
            if (temporaryReferrer != BURN_ADDRESS) {
                referrerRealBalances[temporaryReferrer] +=
                    (temporaryReferralRealAmounts[referrals[i]] *
                        firstLevelRefPercent) /
                    TAX_PERCENT_DENORM; // 1.00%
                emit ReferrerRewardUpdated(
                    temporaryReferrer,
                    referrerRealBalances[temporaryReferrer]
                );

                temporaryReferrer = referralToReferrer[temporaryReferrer]; // Finding second-level referrer on top of first-level referrer
                if (temporaryReferrer != BURN_ADDRESS) {
                    referrerRealBalances[temporaryReferrer] +=
                        (temporaryReferralRealAmounts[referrals[i]] *
                            secondLevelRefPercent) /
                        TAX_PERCENT_DENORM; // 0.25%
                    emit ReferrerRewardUpdated(
                        temporaryReferrer,
                        referrerRealBalances[temporaryReferrer]
                    );
                }

                temporaryReferralRealAmounts[referrals[i]] = 0;
            }
        }
    }

    function getTemporaryReferralRealAmountsBulk(address[] calldata addrs)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (TemporaryReferralRealAmountsBulk[] memory)
    {
        TemporaryReferralRealAmountsBulk[]
            memory output = new TemporaryReferralRealAmountsBulk[](
                addrs.length
            );
        for (uint256 i = 0; i < addrs.length; i++) {
            output[i] = TemporaryReferralRealAmountsBulk(
                addrs[i],
                temporaryReferralRealAmounts[addrs[i]]
            );
        }

        return output;
    }

    function filterNonZeroReferrals(address[] calldata referrals)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (address[] memory)
    {
        address[] memory output = referrals;
        for (uint256 i = 0; i < referrals.length; i++) {
            if (temporaryReferralRealAmounts[referrals[i]] == 0) {
                output[i] = BURN_ADDRESS;
            }
        }

        return output;
    }

    function getCachedReferrerRewards(address referrer)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint256)
    {
        return
            (referrerRealBalances[referrer] * cachedMultiplier) /
            BALANCE_MULTIPLIER_DENORM;
    }

    function clearReferrerRewards(address addr) external onlyRole(ROLE_ADMIN) {
        referrerRealBalances[addr] = 0;
    }

    function registerReferral(address referral, address referrer)
        external
        onlyRole(ROLE_ADMIN)
    {
        require(
            referrer != BURN_ADDRESS && referral != BURN_ADDRESS,
            "NBT: !burn"
        );
        require(referrer != referral, "NBT: !self_ref");
        require(
            referrer != referralToReferrer[referral] &&
                referral != referralToReferrer[referrer],
            "NBT: !mutual_ref"
        );
        require(
            isNotContract(referral) && isNotContract(referrer),
            "NBT: !contract"
        );
        require(
            !hasRole(ROLE_WHITELIST, referral) &&
                !hasRole(ROLE_WHITELIST, referrer) &&
                !hasRole(ROLE_CUSTOM_TAX, referral) &&
                !hasRole(ROLE_CUSTOM_TAX, referrer),
            "NBT: !w_ct"
        );

        referralToReferrer[referral] = referrer;
        if (referralToReferrer[referral] != BURN_ADDRESS) // referrer exists
        {
            emit ReferrerReplaced(
                referral,
                referralToReferrer[referral],
                referrer
            );
        } else {
            emit ReferralRegistered(referral, referrer);
        }
    }

    function updateReCachePeriod(uint256 _secondsBetweenUpdates)
        external
        onlyRole(ROLE_ADMIN)
    {
        secondsBetweenUpdates = _secondsBetweenUpdates;
    }

    function updateCustomTaxForAddress(
        address addr,
        uint256 newCustomTaxPercent
    ) external onlyRole(ROLE_ADMIN) {
        customTaxPercents[addr] = newCustomTaxPercent;
        _setupRole(ROLE_CUSTOM_TAX, addr);
    }

    function updateTaxPercent(
        uint256 _refTaxPercent,
        uint256 _botTaxPercent,
        uint256 _humanTaxPercent,
        uint256 _firstLevelRefPercent,
        uint256 _secondLevelRefPercent
    ) external onlyRole(ROLE_ADMIN) {
        refTaxPercent = _refTaxPercent;
        botTaxPercent = _botTaxPercent;
        humanTaxPercent = _humanTaxPercent;
        firstLevelRefPercent = _firstLevelRefPercent;
        secondLevelRefPercent = _secondLevelRefPercent;
    }

    function isNotContract(address account) private view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(account)
        }
        return size == 0;
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

    function delayedUpdateCacheMultiplier() private {
        if (block.timestamp > lastCachedTimestamp + secondsBetweenUpdates) {
            forcedUpdateCacheMultiplier();
        }
    }

    function forcedUpdateCacheMultiplier() private {
        lastCachedTimestamp = block.timestamp;

        realTotalSupply -= batchBurnAndReward;
        rewardsBalance += batchBurnAndReward / 2; // Half of burned amount goes to rewards to all DEFT holders
        batchBurnAndReward = 0;

        cachedMultiplier =
            BALANCE_MULTIPLIER_DENORM +
            (BALANCE_MULTIPLIER_DENORM * rewardsBalance) /
            realTotalSupply;

        emit MultiplierUpdated(cachedMultiplier);
    }

    function publicForcedUpdateCacheMultiplier() public {
        forcedUpdateCacheMultiplier();
    }

    function chargeCustomTax(uint256 taxAmount, uint256 accountBalance)
        external
        onlyRole(ROLE_ADMIN)
        returns (uint256)
    {
        uint256 realTaxAmount = (taxAmount * BALANCE_MULTIPLIER_DENORM) /
            cachedMultiplier;

        accountBalance -= realTaxAmount;
        batchBurnAndReward += realTaxAmount;

        delayedUpdateCacheMultiplier();

        return accountBalance;
    }

    function chargeCustomTaxTeamVestingContract(
        uint256 taxAmount,
        uint256 accountBalance
    ) external onlyRole(ROLE_ADMIN) returns (uint256) {
        accountBalance -= taxAmount;
        batchBurnAndReward += taxAmount;

        delayedUpdateCacheMultiplier();

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

        uint256 burnAndRewardRealAmount;
        if (
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
                (sentOrReceivedAtBlockStorage[taxAmountsInput.sender]
                    .receivedAtBlock +
                    howManyBlocksAgoReceived <
                    block.number &&
                    isNotContract(taxAmountsInput.sender))) &&
            (hasRole(ROLE_WHITELIST, taxAmountsInput.recipient) ||
                (sentOrReceivedAtBlockStorage[taxAmountsInput.recipient]
                    .sentAtBlock +
                    howManyBlocksAgoSent <
                    block.number &&
                    isNotContract(taxAmountsInput.recipient)))
        ) {
            // isHuman
            if (
                // For example for binance wallet/contract I can set custom tax = 0%
                hasRole(ROLE_CUSTOM_TAX, taxAmountsInput.sender) ||
                hasRole(ROLE_CUSTOM_TAX, taxAmountsInput.recipient)
            ) {
                // Getting actual tax of sender or recipient
                uint256 customTax = customTaxPercents[
                    hasRole(ROLE_CUSTOM_TAX, taxAmountsInput.recipient)
                        ? taxAmountsInput.recipient
                        : taxAmountsInput.sender
                ];
                burnAndRewardRealAmount =
                    (realTransferAmount * customTax) /
                    TAX_PERCENT_DENORM;
            } else if (
                // Sender & recipient don't have any referrers and no custom tax
                referralToReferrer[taxAmountsInput.sender] == BURN_ADDRESS &&
                referralToReferrer[taxAmountsInput.recipient] == BURN_ADDRESS
            ) {
                burnAndRewardRealAmount =
                    (realTransferAmount * humanTaxPercent) /
                    TAX_PERCENT_DENORM;
            }
            // If sender or recipient is referral under referralToReferrer[taxAmountsInput.sender] referrer
            else {
                burnAndRewardRealAmount =
                    (realTransferAmount * refTaxPercent) /
                    TAX_PERCENT_DENORM;

                temporaryReferralRealAmounts[
                    referralToReferrer[taxAmountsInput.recipient] !=
                        BURN_ADDRESS
                        ? taxAmountsInput.recipient
                        : taxAmountsInput.sender
                ] += realTransferAmount;
            }
        } else {
            // isBot
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

        // Saving when sender (or recipient) made last transaction for anti bot system
        sentOrReceivedAtBlockStorage[taxAmountsInput.recipient]
            .receivedAtBlock = block.number;
        sentOrReceivedAtBlockStorage[taxAmountsInput.sender].sentAtBlock = block
            .number;

        delayedUpdateCacheMultiplier();

        return taxAmountsOutput;
    }

    function prepareHumanAddressMintOrBurnRewardsAmounts(
        bool isMint,
        address account,
        uint256 desiredAmountToMintOrBurn
    ) external onlyRole(ROLE_ADMIN) returns (uint256) {
        require(
            hasRole(ROLE_WHITELIST, account) || isNotContract(account),
            "NBT: !human"
        );

        uint256 realAmountToMintOrBurn = (BALANCE_MULTIPLIER_DENORM *
            desiredAmountToMintOrBurn) / cachedMultiplier;
        uint256 rewardToMintOrBurn = desiredAmountToMintOrBurn -
            realAmountToMintOrBurn;
        if (isMint) {
            rewardsBalance += rewardToMintOrBurn;
            realTotalSupply += realAmountToMintOrBurn;
        } else {
            rewardsBalance -= rewardToMintOrBurn;
            realTotalSupply -= realAmountToMintOrBurn;
        }

        forcedUpdateCacheMultiplier();

        return realAmountToMintOrBurn;
    }

    function getBalance(address account, uint256 accountBalance)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint256)
    {
        return
            hasRole(ROLE_EXCLUDE_FROM_BALANCE, account)
                ? accountBalance
                : (accountBalance * cachedMultiplier) /
                    BALANCE_MULTIPLIER_DENORM;
    }

    function getRealBalanceTeamVestingContract(uint256 accountBalance)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint256)
    {
        return (accountBalance * BALANCE_MULTIPLIER_DENORM) / cachedMultiplier;
    }

    function getRealBalance(address account, uint256 accountBalance)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint256)
    {
        return
            hasRole(ROLE_EXCLUDE_FROM_BALANCE, account)
                ? accountBalance
                : (accountBalance * BALANCE_MULTIPLIER_DENORM) /
                    cachedMultiplier;
    }
}
