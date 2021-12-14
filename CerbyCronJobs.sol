// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

struct CronJob {
    address targetContract;
    bytes4 signature;
}

contract CerbyCronJobs {

    CronJob[] public cronJobs;

    constructor() {
    }

    function registerJob(address targetContract, string calldata abiCall)
        public
    {
        CronJob memory cronJob;
        cronJob.targetContract = targetContract;
        cronJob.signature = bytes4(abi.encodeWithSignature(abiCall));

        bool foundGap;
        for(uint i; i<cronJobs.length; i++)
        {
            if (cronJobs[i].targetContract == address(0x0))
            {
                foundGap = true;
                cronJobs[i] = cronJob;
                break;
            }
        }

        if (!foundGap)
        {
            cronJobs.push(
                cronJob
            );
        }
    }

    function removeJobs(address targetContract)
        public
    {
        for(uint i; i<cronJobs.length; i++)
        {
            if (cronJobs[i].targetContract == targetContract)
            {
                delete cronJobs[i];
            }
        }
    }

    function getCronJobsLength()
        public
        view
        returns (uint)
    {
        return cronJobs.length;
    }
    
    function executeJobs()
        public
    {
        for(uint i; i<cronJobs.length; i++)
        {            
            address(cronJobs[i].targetContract).
                call(abi.encodePacked(cronJobs[i].signature));
        }
    }
}