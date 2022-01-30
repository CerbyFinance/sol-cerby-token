// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.10;

import "./interfaces/ICerbyBotDetection.sol";
import "./interfaces/ICerbyToken.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";

struct TaxAmountsInput {
    address sender;
    address recipient;
    uint256 transferAmount;
    uint256 senderRealBalance;
    uint256 recipientRealBalance;
}
struct TaxAmountsOutput {
    uint256 senderRealBalance;
    uint256 recipientRealBalance;
    uint256 burnAndRewardAmount;
    uint256 recipientGetsAmount;
}

/* deploy:
1. updateCerbyTokenAddress
2. updateTotalSupply
3. give admin to CerbyBotDetection
4. updateUtilsContracts

*/

contract NoBotsTechV3 is AccessControlEnumerable {
    uint256 constant CERBY_BOT_DETECTION_CONTRACT_ID = 3;

    address cerbyTokenAddress;

    address constant BURN_ADDRESS = address(0x0);

    uint256 realTotalSupply;

    constructor() {
        _setupRole(ROLE_ADMIN, _msgSender());

        updateCerbyTokenAddress(0xdef1fac7Bf08f173D286BbBDcBeeADe695129840);
    }

    function updateTotalSupply(uint256 _realTotalSupply)
        external
        onlyRole(ROLE_ADMIN)
    {
        realTotalSupply = _realTotalSupply;
    }

    function updateCerbyTokenAddress(address _cerbyTokenAddress)
        public
        onlyRole(ROLE_ADMIN)
    {
        cerbyTokenAddress = _cerbyTokenAddress;
        _setupRole(ROLE_ADMIN, _cerbyTokenAddress);
    }

    function getTotalSupply()
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint256)
    {
        return realTotalSupply;
    }

    function publicForcedUpdateCacheMultiplier() public {
        // Do nothing, for compability
    }

    function prepareTaxAmounts(TaxAmountsInput calldata taxAmountsInput)
        external
        onlyRole(ROLE_ADMIN)
        returns (TaxAmountsOutput memory taxAmountsOutput)
    {
        require(taxAmountsInput.transferAmount > 0, "NBT: !amount");

        ICerbyBotDetection iCerbyBotDetection = ICerbyBotDetection(
            ICerbyToken(cerbyTokenAddress).getUtilsContractAtPos(
                CERBY_BOT_DETECTION_CONTRACT_ID
            )
        );
        iCerbyBotDetection.checkTransactionInfo(
            cerbyTokenAddress,
            taxAmountsInput.sender,
            taxAmountsInput.recipient,
            taxAmountsOutput.recipientRealBalance,
            taxAmountsInput.transferAmount
        );

        taxAmountsOutput.senderRealBalance =
            taxAmountsInput.senderRealBalance -
            taxAmountsInput.transferAmount;
        taxAmountsOutput.recipientRealBalance =
            taxAmountsInput.recipientRealBalance +
            taxAmountsInput.transferAmount;

        //taxAmountsOutput.burnAndRewardAmount = 0; // Actual amount we burned and have to show in event
        taxAmountsOutput.recipientGetsAmount = taxAmountsInput.transferAmount; // Actual amount recipient got and have to show in event

        return taxAmountsOutput;
    }

    function prepareHumanAddressMintOrBurnRewardsAmounts(
        bool isMint,
        address,
        uint256 desiredAmountToMintOrBurn
    ) external onlyRole(ROLE_ADMIN) returns (uint256) {
        if (isMint) {
            realTotalSupply += desiredAmountToMintOrBurn;
        } else {
            realTotalSupply -= desiredAmountToMintOrBurn;
        }

        return desiredAmountToMintOrBurn;
    }

    function getBalance(address, uint256 accountBalance)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint256)
    {
        return accountBalance;
    }

    function getRealBalanceTeamVestingContract(uint256 accountBalance)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint256)
    {
        return accountBalance;
    }
}
