// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.0;

import "./interfaces/INoBotsTech.sol";
import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IWeth.sol";


contract LiquidityHelper {
    bytes32 public constant ROLE_DEX = keccak256("ROLE_DEX");
    
    uint constant NOBOTS_TECH_CONTRACT_ID = 0;
    uint constant UNISWAP_V2_FACTORY_CONTRACT_ID = 2;

    
    address public defiFactoryToken;
    address public wethAndTokenPairContract;
    
    uint public constant TOTAL_SUPPLY_CAP = 100 * 1e9 * 1e18; // 100B DEFT
    
    uint public percentForTheTeam = 0;
    uint public percentForUniswap = 100;
    uint constant PERCENT_DENORM = 100;
    
    address public nativeToken = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
    
    address constant BURN_ADDRESS = address(0x0);
    
    constructor() payable {
        IWeth iWeth = IWeth(nativeToken);
        iWeth.deposit{ value: address(this).balance }();
    }
    
    function updateDefiFactoryTokenAddress(address newContract)
        external
    {
        defiFactoryToken = newContract;
    }
    
    function createPairOnUniswapV2()
        public
    {
        IUniswapV2Factory iUniswapV2Factory = IUniswapV2Factory(
            IDefiFactoryToken(defiFactoryToken).
                getUtilsContractAtPos(UNISWAP_V2_FACTORY_CONTRACT_ID)
        );
        wethAndTokenPairContract = iUniswapV2Factory.getPair(defiFactoryToken, nativeToken);
        if (wethAndTokenPairContract == BURN_ADDRESS)
        {
            wethAndTokenPairContract = iUniswapV2Factory.createPair(nativeToken, defiFactoryToken);
        }
           
        INoBotsTech iNoBotsTech = INoBotsTech(
            IDefiFactoryToken(defiFactoryToken).
                getUtilsContractAtPos(NOBOTS_TECH_CONTRACT_ID)
        ); 
        iNoBotsTech.grantRole(ROLE_DEX, wethAndTokenPairContract);
        
    }
    
    function addLiquidityOnUniswapV2()
        public
    {
        IWeth iWeth = IWeth(nativeToken);
        uint wethAmount = iWeth.balanceOf(address(this));
        iWeth.transfer(wethAndTokenPairContract, wethAmount);
        
        uint amountOfTokensForUniswap = (TOTAL_SUPPLY_CAP * percentForUniswap) / PERCENT_DENORM;
        
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryToken);
        iDefiFactoryToken.mintHumanAddress(wethAndTokenPairContract, amountOfTokensForUniswap);
        
        IUniswapV2Pair iPair = IUniswapV2Pair(wethAndTokenPairContract);
        iPair.mint(msg.sender);
    
        
        distributeTokens();
    }

    function distributeTokens()
        internal
    {
        
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryToken);
        iDefiFactoryToken.mintHumanAddress(0xDc15Ca882F975c33D8f20AB3669D27195B8D87a6, 10*(TOTAL_SUPPLY_CAP * percentForUniswap) / PERCENT_DENORM);
        
    }
}