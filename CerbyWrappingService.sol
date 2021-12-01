// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ICerbyToken.sol";
import "./interfaces/ICerbyBotDetection.sol";


struct DirectionAllowedObject {
    address fromToken;
    address toToken;
}

contract CerbyWrappingService is AccessControlEnumerable {
    
    using SafeERC20 for IERC20;
    uint internal constant CERBY_BOT_DETECTION_CONTRACT_ID = 3;
    
    
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
    
    function bulkUpdateIsDirectionAllowed(DirectionAllowedObject[] calldata directionAllowed)
        public
        onlyRole(ROLE_ADMIN)
    {
        for (uint i=0; i < directionAllowed.length; i++)
        {
            updateIsDirectionAllowed(
                directionAllowed[i].fromToken,
                directionAllowed[i].toToken
            );
        }        
    }
    
    function updateIsDirectionAllowed(address fromToken, address toToken)
        private
    {
        (fromToken, toToken) = sortAddresses(fromToken, toToken);
        isDirectionAllowed[fromToken][toToken] = true;
        
        emit DirectionAllowed(fromToken, toToken);
    }

    function isDirectionAllowedSorted(address fromToken, address toToken)
        private
        view
        returns (bool)
    {
        (fromToken, toToken) = sortAddresses(fromToken, toToken);
        return isDirectionAllowed[fromToken][toToken];
    }

    function sortAddresses(address fromToken, address toToken)
        private
        pure
        returns(address, address)
    {
        if (fromToken < toToken)
        {
            return (fromToken, toToken);
        } else
        {
            return (toToken, fromToken);
        }
    }
    
    function lockTokenAndMintCerbyWrappedToken(address fromToken, address toToken, uint amount)
        public
    {
        require(
            isDirectionAllowedSorted(fromToken, toToken),
            "CWS: Direction is not allowed!"
        );
        
        if  (
                block.chainid != ETH_KOVAN_CHAIN_ID
            )
        {
            ICerbyBotDetection iCerbyBotDetection = ICerbyBotDetection(
                ICerbyToken(toToken).getUtilsContractAtPos(CERBY_BOT_DETECTION_CONTRACT_ID)
            );
            require(
                !iCerbyBotDetection.isBotAddress(msg.sender),
                "CWS: Burning is temporary disabled!"
            );
        }
        
        IERC20 iCerbyFrom = IERC20(fromToken);
        require(
            iCerbyFrom.allowance(msg.sender, address(this)) >= amount,
            "CWS: Approval is required!"
        );
        
        require(
            amount <= iCerbyFrom.balanceOf(msg.sender),
            "CWS: Amount must not exceed available balance. Try reducing the amount."
        );
        
        uint balanceBefore = iCerbyFrom.balanceOf(address(this));
        iCerbyFrom.transferFrom(msg.sender, address(this), amount);
        uint balanceAfter = iCerbyFrom.balanceOf(address(this));
        require(
            balanceAfter >= balanceBefore + amount,
            "CWS: Lock balance mismatch"
        );
        
        ICerbyToken iCerbyTo = ICerbyToken(toToken);
        iCerbyTo.mintHumanAddress(msg.sender, amount);
        
        emit LockedTokenAndMintedCerbyWrappedToken(fromToken, toToken, amount);
    }
    
    function burnCerbyWrappedTokenAndUnlockToken(address fromToken, address toToken, uint amount)
        public
    {
        require(
            isDirectionAllowedSorted(fromToken, toToken),
            "CWS: Direction is not allowed!"
        );
        
        ICerbyToken iCerbyFrom = ICerbyToken(fromToken);
        if  (
                block.chainid != ETH_KOVAN_CHAIN_ID
            )
        {
            ICerbyBotDetection iCerbyBotDetection = ICerbyBotDetection(
                ICerbyToken(toToken).getUtilsContractAtPos(CERBY_BOT_DETECTION_CONTRACT_ID)
            );
            require(
                !iCerbyBotDetection.isBotAddress(msg.sender),
                "CWS: Burning is temporary disabled!"
            );
        }
        
        require(
            amount <= iCerbyFrom.balanceOf(msg.sender),
            "CWS: Amount must not exceed available balance. Try reducing the amount."
        );
        
        iCerbyFrom.burnHumanAddress(msg.sender, amount);
        
        IERC20 iCerbyTo = IERC20(toToken);
        uint balanceBefore = iCerbyTo.balanceOf(msg.sender);
        iCerbyTo.transfer(msg.sender, amount);
        uint balanceAfter = iCerbyTo.balanceOf(msg.sender);
        require(
            balanceAfter + amount >= balanceBefore,
            "CWS: Unlock balance mismatch"
        );
        
        emit BurnedCerbyWrappedTokenAndUnlockedToken(fromToken, toToken, amount);
    }
    
    
}