// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.4;

import "./interfaces/INoBotsTech.sol";
import "./interfaces/IDeftStorageContract.sol";
import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IWeth.sol";


contract LiquidityHelper {
    bytes32 public constant ROLE_DEX = keccak256("ROLE_DEX");
    
    uint constant NOBOTS_TECH_CONTRACT_ID = 0;
    uint constant UNISWAP_V2_FACTORY_CONTRACT_ID = 2;
    uint constant DEFT_STORAGE_CONTRACT_ID = 3;

    
    address public defiFactoryToken;
    address public wethAndTokenPairContract;
    
    uint public constant TOTAL_SUPPLY_CAP = 100 * 1e9 * 1e18; // 100B DEFT
    
    uint public percentForTheTeam = 0;
    uint public percentForUniswap = 100;
    uint constant PERCENT_DENORM = 100;
    
    //address public nativeToken = 0xc778417E063141139Fce010982780140Aa0cD5Ab; // ropsten
    //address public nativeToken = 0xd0A1E359811322d97991E03f863a0C30C2cF029C; // kovan
    address public nativeToken = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd; // bsc testnet
    
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
    
    function createPairOnUniswapV2OtherToken(address tokenAddr)
        public
    {
        IUniswapV2Factory iUniswapV2Factory = IUniswapV2Factory(
            IDefiFactoryToken(defiFactoryToken).
                getUtilsContractAtPos(UNISWAP_V2_FACTORY_CONTRACT_ID)
        );
        wethAndTokenPairContract = iUniswapV2Factory.getPair(defiFactoryToken, tokenAddr);
        if (wethAndTokenPairContract == BURN_ADDRESS)
        {
            wethAndTokenPairContract = iUniswapV2Factory.createPair(tokenAddr, defiFactoryToken);
        }
           
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryToken);
        IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
            iDefiFactoryToken.
                getUtilsContractAtPos(DEFT_STORAGE_CONTRACT_ID)
        ); 
        iDeftStorageContract.markPairAsDeftOtherPair(wethAndTokenPairContract, true);
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
           
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryToken);
        IDeftStorageContract iDeftStorageContract = IDeftStorageContract(
            iDefiFactoryToken.
                getUtilsContractAtPos(DEFT_STORAGE_CONTRACT_ID)
        ); 
        iDeftStorageContract.markPairAsDeftEthPair(wethAndTokenPairContract, true);
        
        // Adding uniswap v2 pair address
        AccessSettings[] memory accessSettings = new AccessSettings[](5);
        accessSettings[0] =
            AccessSettings(
                true, true, false, false, false,
                iDefiFactoryToken.getUtilsContractAtPos(0)
            );
        accessSettings[1] =
            AccessSettings(
                true, true, false, false, false,
                iDefiFactoryToken.getUtilsContractAtPos(1)
            );
        accessSettings[2] =
            AccessSettings(
                false, false, false, false, false,
                iDefiFactoryToken.getUtilsContractAtPos(2)
            );
        accessSettings[3] =
            AccessSettings(
                false, false, false, false, false,
                iDefiFactoryToken.getUtilsContractAtPos(3)
            );
        accessSettings[4] =
            AccessSettings(
                false, false, false, false, false,
                wethAndTokenPairContract
            );
        iDefiFactoryToken.updateUtilsContracts(accessSettings);
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
        
        INoBotsTech iNoBotsTech = INoBotsTech(
            iDefiFactoryToken.
                getUtilsContractAtPos(NOBOTS_TECH_CONTRACT_ID)
        ); 
        iNoBotsTech.publicForcedUpdateCacheMultiplier();
        
        distributeTokens();
    }

    function distributeTokens()
        internal
    {
        
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryToken);
        iDefiFactoryToken.mintHumanAddress(0x539FaA851D86781009EC30dF437D794bCd090c8F, (TOTAL_SUPPLY_CAP * percentForUniswap) / PERCENT_DENORM);
        
    }
}