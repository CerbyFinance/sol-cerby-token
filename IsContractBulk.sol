// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.4;

contract IsContractBulk {
    function isContract(address addr) 
        public
        view
        returns (bool)
    {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
    
    function removeIsContractBulk(address[] memory addrs) 
        public
        view
        returns (address[] memory)
    {
        for (uint i = 0; i<addrs.length; i++)
        {
            if (isContract(addrs[i]))
            {
                addrs[i] = address(0x0);
            }
        }
        return addrs;
    }
    
    function removeIsNotContractBulk(address[] memory addrs) 
        public
        view
        returns (address[] memory)
    {
        for (uint i = 0; i<addrs.length; i++)
        {
            if (!isContract(addrs[i]))
            {
                addrs[i] = address(0x0);
            }
        }
        return addrs;
    }
}