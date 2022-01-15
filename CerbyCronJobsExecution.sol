// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.11;

import "./interfaces/ICerbyToken.sol";
import "./interfaces/ICerbyBotDetection.sol";

abstract contract CerbyCronJobsExecution {

    uint internal constant CERBY_BOT_DETECTION_CONTRACT_ID = 3;
    address internal constant CERBY_TOKEN_CONTRACT_ADDRESS = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840;
    
    modifier checkForBotsAndExecuteCronJobs(address addr)
    {
        ICerbyBotDetection iCerbyBotDetection = ICerbyBotDetection(
            getUtilsContractAtPos(CERBY_BOT_DETECTION_CONTRACT_ID)
        );
        require(
            !iCerbyBotDetection.isBotAddress(addr),
            "CCJE: Transactions are temporarily disabled"
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
            "CCJE: Transactions are temporarily disabled"
        );
        _;
    }
    
    modifier checkTransaction(address tokenAddr, address addr)
    {
        ICerbyBotDetection iCerbyBotDetection = ICerbyBotDetection(
            ICerbyToken(CERBY_TOKEN_CONTRACT_ADDRESS).getUtilsContractAtPos(CERBY_BOT_DETECTION_CONTRACT_ID)
        );
        require(
            !iCerbyBotDetection.checkTransaction(tokenAddr, addr),
            "CCJE: Transactions are temporarily disabled"
        );
        _;
    }
}
