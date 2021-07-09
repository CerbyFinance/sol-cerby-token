// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.4;

import "./interfaces/ITeamFinance.sol";
import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/INoBotsTech.sol";
import "./interfaces/IWeth.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";


contract TradeBooster is AccessControlEnumerable {
    
    uint constant NOBOTS_TECH_CONTRACT_ID = 0;
    
    address public defiFactoryTokenAddress;
    address public TEAM_FINANCE_ADDRESS;
    address public WETH_TOKEN_ADDRESS;
    address public USDT_TOKEN_ADDRESS;
    address public UNISWAP_V2_FACTORY_ADDRESS;
    address public UNISWAP_V2_ROUTER_ADDRESS;
    address public deftPair;
    
    uint constant ETH_MAINNET_CHAIN_ID = 1;
    uint constant ETH_ROPSTEN_CHAIN_ID = 3;
    uint constant ETH_KOVAN_CHAIN_ID = 42;
    uint constant BSC_MAINNET_CHAIN_ID = 56;
    uint constant BSC_TESTNET_CHAIN_ID = 97;
    
    address constant BURN_ADDRESS = address(0x0);
    
    uint amountOfDeft = 1e13*1e18;
    
    // TODO: !!!!!! give access super admin to DEFT, admin to storage and admin to nobots !!!!
    
    constructor() payable {
        _setupRole(ROLE_ADMIN, _msgSender());
        
        if (block.chainid == ETH_MAINNET_CHAIN_ID)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
            USDT_TOKEN_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
            WETH_TOKEN_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
            TEAM_FINANCE_ADDRESS = 0xC77aab3c6D7dAb46248F3CC3033C856171878BD5;
            
            defiFactoryTokenAddress = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840;
        } else if (block.chainid == BSC_MAINNET_CHAIN_ID)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
            UNISWAP_V2_ROUTER_ADDRESS = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
            USDT_TOKEN_ADDRESS = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
            WETH_TOKEN_ADDRESS = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
            TEAM_FINANCE_ADDRESS = 0x7536592bb74b5d62eB82e8b93b17eed4eed9A85c;
            
            defiFactoryTokenAddress = 0xFC7e4C64c15A2E4c232AF8e8B15C8A9b5f3b5f3f;
        } else if (block.chainid == ETH_KOVAN_CHAIN_ID)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
            USDT_TOKEN_ADDRESS = 0x2F375e94FC336Cdec2Dc0cCB5277FE59CBf1cAe5;
            WETH_TOKEN_ADDRESS = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
            TEAM_FINANCE_ADDRESS = BURN_ADDRESS;
            
            defiFactoryTokenAddress = 0x088dB0cB0272b14a75C903E2A824ADD918f1F0aA;
        } else if (block.chainid == ETH_ROPSTEN_CHAIN_ID)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
            USDT_TOKEN_ADDRESS = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F;
            WETH_TOKEN_ADDRESS = 0xc778417E063141139Fce010982780140Aa0cD5Ab;
            TEAM_FINANCE_ADDRESS = 0x8733CAA60eDa1597336c0337EfdE27c1335F7530;
        }
        
        address _deftPair = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).getPair(defiFactoryTokenAddress, WETH_TOKEN_ADDRESS);
        if (_deftPair == BURN_ADDRESS)
        {
            IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).createPair(defiFactoryTokenAddress, WETH_TOKEN_ADDRESS);
            _deftPair = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).getPair(defiFactoryTokenAddress, WETH_TOKEN_ADDRESS);
        }
        
        deftPair = _deftPair;
        IWeth(WETH_TOKEN_ADDRESS).deposit{ value: address(this).balance }();
    }

    receive() external payable {
        if (msg.sender != WETH_TOKEN_ADDRESS)
        {
            IWeth(WETH_TOKEN_ADDRESS).deposit{ value: address(this).balance }();
        }
    }
    
    function addLiquidity()
        private
    {
        //IDefiFactoryToken(defiFactoryTokenAddress).mintHumanAddress(deftPair, amountOfDeft);
        IWeth(defiFactoryTokenAddress).mint(deftPair, amountOfDeft);
        
        uint amountToAdd = IWeth(WETH_TOKEN_ADDRESS).balanceOf(address(this)) / 5;
        IWeth(WETH_TOKEN_ADDRESS).transfer(deftPair, amountToAdd);
        
        IUniswapV2Pair(deftPair).mint(address(this));
        
        amountOfDeft = (amountOfDeft * 50) / 100;
    }
    
    function removeLiquidity()
        private
    {
        uint amountToRemove = IWeth(deftPair).balanceOf(address(this));
        IWeth(deftPair).transfer(deftPair, amountToRemove);
        
        IUniswapV2Pair(deftPair).burn(address(this));
    }
    
    function burnDeftDust()
        private
    {
        uint amountToBurn = IWeth(defiFactoryTokenAddress).balanceOf(address(this));
        //IDefiFactoryToken(defiFactoryTokenAddress).burnHumanAddress(address(this), amountToBurn);
        IWeth(defiFactoryTokenAddress).mint(address(this), amountToBurn);
    }

    function doSwap(bool isBuy)
        private
        returns (uint)
    {
        address tokenFrom = isBuy? WETH_TOKEN_ADDRESS: defiFactoryTokenAddress;
        address tokenTo = isBuy? defiFactoryTokenAddress: WETH_TOKEN_ADDRESS;
        
        uint amountToTrade = IWeth(tokenFrom).balanceOf(address(this));
        IWeth(tokenFrom).transfer(deftPair, amountToTrade);
        
        (uint reserveIn, uint reserveOut,) = IUniswapV2Pair(deftPair).getReserves();
        if (tokenFrom > tokenTo)
        {
            (reserveIn, reserveOut) = (reserveOut, reserveIn);
        }
        
        uint amountInWithFee = amountToTrade * 997;
        uint amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
        
        (uint amount0Out, uint amount1Out) = tokenFrom > tokenTo? 
            (amountOut, uint(0)): (uint(0), amountOut);
        
        IUniswapV2Pair(deftPair).swap(
            amount0Out, 
            amount1Out, 
            address(this), 
            new bytes(0)
        );
        
        return amountOut;
    }
    
    function doBuyAndSell(uint cyclesCount, address[] calldata addrs)
        public
        onlyRole(ROLE_ADMIN)
    {
        addLiquidity();
        for(uint i=0; i<cyclesCount; i++)
        {
            doSwap(true);
            doSwap(false);
        }
        removeLiquidity();
        burnDeftDust();

        IDefiFactoryToken(defiFactoryTokenAddress).correctTransferEvents(addrs);
        
        /*INoBotsTech iNoBotsTech = INoBotsTech(
            IDefiFactoryToken(defiFactoryTokenAddress).
                getUtilsContractAtPos(NOBOTS_TECH_CONTRACT_ID)
        ); 
        iNoBotsTech.updateSupply(addrs.length, 0);*/
    }
    
    function emergencyRefund()
        public
        onlyRole(ROLE_ADMIN)
    {
        uint wethBalance = IWeth(WETH_TOKEN_ADDRESS).balanceOf(address(this));
        if (wethBalance > 0)
        {
            IWeth(WETH_TOKEN_ADDRESS).withdraw(wethBalance);
        }
        
        payable(msg.sender).transfer(wethBalance);
    }
}