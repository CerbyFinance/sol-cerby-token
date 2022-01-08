// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.11;

import "./interfaces/ICerbyToken.sol";
import "./interfaces/ICerbyBotDetection.sol";

contract CerbyCronJobsExecution {

    uint internal constant CERBY_BOT_DETECTION_CONTRACT_ID = 3;
    address internal constant CERBY_TOKEN_CONTRACT_ADDRESS = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840;
    
    modifier executeCronJobs()
    {
        ICerbyBotDetection iCerbyBotDetection = ICerbyBotDetection(
            getUtilsContractAtPos(CERBY_BOT_DETECTION_CONTRACT_ID)
        );
        iCerbyBotDetection.executeCronJobs();
        _;
    }


    function getUtilsContractAtPos(uint pos)
        public
        view
        virtual
        returns (address)
    {
        return ICerbyToken(CERBY_TOKEN_CONTRACT_ADDRESS).getUtilsContractAtPos(pos);
    }
    
    modifier checkForBots(address addr)
    {
        ICerbyBotDetection iCerbyBotDetection = ICerbyBotDetection(
            ICerbyToken(CERBY_TOKEN_CONTRACT_ADDRESS).getUtilsContractAtPos(CERBY_BOT_DETECTION_CONTRACT_ID)
        );
        require(
            !iCerbyBotDetection.isBotAddress(addr),
            "CCJE: Transactions are temporary disabled"
        );
        _;
    }
}