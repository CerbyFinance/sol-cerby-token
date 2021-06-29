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
    
    address UNISWAP_V2_FACTORY_ADDRESS;
    address WETH_TOKEN_ADDRESS;
    address parentTokenAddress;
    
    address constant BURN_ADDRESS = address(0x0);
    
    constructor() payable {
        if (block.chainid == 1)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            WETH_TOKEN_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
            
            parentTokenAddress = BURN_ADDRESS; // TODO: change
        } else if (block.chainid == 56)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0xBCfCcbde45cE874adCB698cC183deBcF17952812;
            WETH_TOKEN_ADDRESS = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
            
            parentTokenAddress = BURN_ADDRESS; // TODO: change
        } else if (block.chainid == 42)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            WETH_TOKEN_ADDRESS = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
            
            parentTokenAddress = 0xC0138126C0Bd394C547df17B649B81B543c76906;
        } else if (block.chainid == 97)
        {
            UNISWAP_V2_FACTORY_ADDRESS = BURN_ADDRESS; // TODO: change
            WETH_TOKEN_ADDRESS = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
            
            parentTokenAddress = BURN_ADDRESS; // TODO: change
        }
        
        IWeth iWeth = IWeth(WETH_TOKEN_ADDRESS);
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
        wethAndTokenPairContract = iUniswapV2Factory.getPair(defiFactoryToken, WETH_TOKEN_ADDRESS);
        if (wethAndTokenPairContract == BURN_ADDRESS)
        {
            wethAndTokenPairContract = iUniswapV2Factory.createPair(WETH_TOKEN_ADDRESS, defiFactoryToken);
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
                true, true, false, false, true,
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
        IWeth iWeth = IWeth(WETH_TOKEN_ADDRESS);
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