// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.4;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/IDeftStorageContract.sol";

contract BalanceStorageContract is AccessControlEnumerable {
    
    mapping(address => mapping(address => uint)) private balances;
    mapping(address => uint) private totalSupply;
    mapping(address => uint) private rewardsBalance;
    
    constructor() {
        _setupRole(ROLE_ADMIN, _msgSender());
    }
    
    function getRealBalance(address _token, address _holder)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint)
    {
        return 
            balances[_token][_holder];
    }
    
    function getBalance(address _token, address _holder)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint)
    {
        return 
            balances[_token][_holder] + 
            (rewardsBalance[_token] * balances[_token][_holder]) / totalSupply[_token];
    }
    
    function getRealValue(address _token, uint _value)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint)
    {
        return _getRealValue(_token, _value);
    }
    
    function getValue(address _token, uint _value)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint)
    {
        return _getValue(_token, _value);
    }
    
    function _getRealValue(address _token, uint _value)
        private
        view
        returns(uint)
    {
        return 
            (_value * totalSupply[_token]) / (totalSupply[_token] + rewardsBalance[_token]);
    }
    
    function _getValue(address _token, uint _value)
        private
        view
        returns(uint)
    {
        return 
            _value + 
            (rewardsBalance[_token] * _value) / totalSupply[_token];
    }
    
    function updateRealBalance(address _token, address _holder, uint newValue)
        public
        onlyRole(ROLE_ADMIN)
    {
        balances[_token][_holder] = newValue;
    }
    
    function updateBalance(address _token, address _holder, uint newValue)
        public
        onlyRole(ROLE_ADMIN)
    {
        balances[_token][_holder] = _getRealValue(_token, newValue);
    }
    
    function addRealBalance(address _token, address _holder, uint addValue)
        public
        onlyRole(ROLE_ADMIN)
    {
        balances[_token][_holder] += addValue;
    }
    
    function addBalance(address _token, address _holder, uint addValue)
        public
        onlyRole(ROLE_ADMIN)
    {
        balances[_token][_holder] += _getRealValue(_token, addValue);
    }
    
    function subRealBalance(address _token, address _holder, uint subValue)
        public
        onlyRole(ROLE_ADMIN)
    {
        balances[_token][_holder] -= subValue;
    }
    
    function subBalance(address _token, address _holder, uint subValue)
        public
        onlyRole(ROLE_ADMIN)
    {
        balances[_token][_holder] -= _getRealValue(_token, subValue);
    }
    
    function getRealTotalSupply(address _token)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint)
    {
        return totalSupply[_token];
    }
    
    function getTotalSupply(address _token)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint)
    {
        return totalSupply[_token] + rewardsBalance[_token];
    }
    
    function updateRealTotalSupply(address _token, uint newValue)
        public
        onlyRole(ROLE_ADMIN)
    {
        totalSupply[_token] = newValue;
    }
    
    function addTotalSupply(address _token, uint addValue)
        public
        onlyRole(ROLE_ADMIN)
    {
        uint realValue = _getRealValue(_token, addValue);
        totalSupply[_token] += realValue;
        rewardsBalance[_token] += addValue - realValue;
    }
    
    function subTotalSupply(address _token, uint subValue)
        public
        onlyRole(ROLE_ADMIN)
    {
        uint realValue = _getRealValue(_token, subValue);
        totalSupply[_token] -= realValue;
        rewardsBalance[_token] -= subValue - realValue;
    }
    
    function getRewardsBalance(address _token)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint)
    {
        return rewardsBalance[_token];
    }
    
    function updateRewardsBalance(address _token, uint newValue)
        public
        onlyRole(ROLE_ADMIN)
    {
        rewardsBalance[_token] = newValue;
    }
    
    function addRewardsBalance(address _token, uint addValue)
        public
        onlyRole(ROLE_ADMIN)
    {
        rewardsBalance[_token] += addValue;
    }
    
    function subRewardsBalance(address _token, uint subValue)
        public
        onlyRole(ROLE_ADMIN)
    {
        rewardsBalance[_token] -= subValue;
    }
}