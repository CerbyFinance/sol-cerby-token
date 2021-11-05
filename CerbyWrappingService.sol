// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.9;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/ICerby.sol";
import "./interfaces/IDeftStorageContract.sol";


contract CerbyWrappingService is AccessControlEnumerable {
    
    uint constant DEFT_STORAGE_CONTRACT_ID = 3;
    
    
    mapping(address => mapping (address => bool)) public isDirectionAllowed;
    
    uint constant ETH_MAINNET_CHAIN_ID = 1;
    uint constant ETH_ROPSTEN_CHAIN_ID = 3;
    uint constant ETH_KOVAN_CHAIN_ID = 42;
    uint constant BSC_MAINNET_CHAIN_ID = 56;
    uint constant BSC_TESTNET_CHAIN_ID = 97;
    uint constant MATIC_MAINNET_CHAIN_ID = 137;
    
    event DirectionAllowed(address fromToken, address toToken);
    event LockedTokenAndMintedCerbyWrappedToken(address fromToken, address toToken, uint amount);
    event BurnedCerbyWrappedTokenAndUnlockedToken(address fromToken, address toToken, uint amount);
    
    
    // 0xF89217f234434105b7f7a8912750D7CC612D7F9e,0x371934cea4f68e78455866325d5b0A7e31cB7387,1000000000000000000
    // 0x371934cea4f68e78455866325d5b0A7e31cB7387,0xF89217f234434105b7f7a8912750D7CC612D7F9e,1000000000000000000
    
    constructor() {
        _setupRole(ROLE_ADMIN, msg.sender);
        
        
        /* Testnet */
        if (block.chainid == ETH_KOVAN_CHAIN_ID)
        {
            updateIsDirectionAllowed(
                0xF89217f234434105b7f7a8912750D7CC612D7F9e,
                0x371934cea4f68e78455866325d5b0A7e31cB7387
            );
        } else if (block.chainid == BSC_TESTNET_CHAIN_ID)
        {
        }
        
        /* MAINNET */
        if (block.chainid == ETH_MAINNET_CHAIN_ID)
        {
        } else if (block.chainid == BSC_MAINNET_CHAIN_ID)
        {
        } else if (block.chainid == MATIC_MAINNET_CHAIN_ID)
        {
        }
    }
    
    function updateIsDirectionAllowed(address fromToken, address toToken)
        public
        onlyRole(ROLE_ADMIN)
    {
        isDirectionAllowed[fromToken][toToken] = true;
        isDirectionAllowed[toToken][fromToken] = true;
        
        emit DirectionAllowed(fromToken, toToken);
    }
    
    function lockTokenAndMintCerbyWrappedToken(address fromToken, address toToken, uint amount)
        public
    {
        require(
            isDirectionAllowed[fromToken][toToken],
            "CWS: Direction is not allowed!"
        );
        
        if (
                block.chainid == ETH_MAINNET_CHAIN_ID ||
                block.chainid == MATIC_MAINNET_CHAIN_ID ||
                block.chainid == BSC_MAINNET_CHAIN_ID
            )
        {
            IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
                defiFactoryToken.getUtilsContractAtPos(DEFT_STORAGE_CONTRACT_ID) // TODO: use defi factory token
            );
            require(
                !iDeftStorageContract.isBotAddress(msg.sender),
                "CWS: Burning is temporary disabled!"
            );
        }
        
        ICerby iCerbyFrom = ICerby(fromToken);
        require(
            iCerbyFrom.allowance(msg.sender, address(this)) >= amount,
            "CWS: Approval is required!"
        );
        
        require(
            amount <= iCerbyFrom.balanceOf(msg.sender),
            "CWS: Amount must not exceed available balance. Try reducing the amount."
        );
        
        uint balanceBefore = iCerbyFrom.balanceOf(address(this));
        iCerbyFrom.transferFrom(msg.sender, address(this), amount); // TODO: use safeTransferFrom
        uint balanceAfter = iCerbyFrom.balanceOf(address(this));
        require(
            balanceAfter >= balanceBefore + amount,
            "CWS: Lock balance mismatch"
        );
        
        ICerby iCerbyTo = ICerby(toToken);
        iCerbyTo.mintHumanAddress(msg.sender, amount);
        
        emit LockedTokenAndMintedCerbyWrappedToken(fromToken, toToken, amount);
    }
    
    function burnCerbyWrappedTokenAndUnlockToken(address fromToken, address toToken, uint amount)
        public
    {
        require(
            isDirectionAllowed[fromToken][toToken],
            "CWS: Direction is not allowed!"
        );
        
        ICerby iCerbyFrom = ICerby(fromToken);
        if (
                block.chainid == ETH_MAINNET_CHAIN_ID ||
                block.chainid == MATIC_MAINNET_CHAIN_ID ||
                block.chainid == BSC_MAINNET_CHAIN_ID
            )
        {
            IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
                defiFactoryToken.getUtilsContractAtPos(DEFT_STORAGE_CONTRACT_ID) // TODO: use defi factory token
            );
            require(
                !iDeftStorageContract.isBotAddress(msg.sender),
                "CWS: Burning is temporary disabled!"
            );
        }
        
        require(
            amount <= iCerbyFrom.balanceOf(msg.sender),
            "CWS: Amount must not exceed available balance. Try reducing the amount."
        );
        
        iCerbyFrom.burnHumanAddress(msg.sender, amount);
        
        ICerby iCerbyTo = ICerby(toToken);
        uint balanceBefore = iCerbyTo.balanceOf(msg.sender);
        iCerbyTo.transfer(msg.sender, amount); // TODO: safeTransfer
        uint balanceAfter = iCerbyTo.balanceOf(msg.sender);
        require(
            balanceAfter + amount >= balanceBefore,
            "CWS: Unlock balance mismatch"
        );
        
        emit BurnedCerbyWrappedTokenAndUnlockedToken(fromToken, toToken, amount);
    }
    
    
}