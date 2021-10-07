// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.7;

import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IWeth.sol";



contract DeftLiquidityMigration {
    
    address owner;
    
    /* Eth 
    address constant UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant WETH_TOKEN_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant DEFT_TOKEN_ADDRESS = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840;*/
    
    /* Bsc */
    address constant UNISWAP_V2_FACTORY_ADDRESS = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address constant UNISWAP_V2_ROUTER_ADDRESS = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address constant WETH_TOKEN_ADDRESS = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant DEFT_TOKEN_ADDRESS = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840;
    
    /* Kovan 
    address constant UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant WETH_TOKEN_ADDRESS = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
    address constant DEFT_TOKEN_ADDRESS = 0x7A7492a8e888Ca3fe8e31cB2E34872FE0CE5309f;*/
    
    /* Process:
        - create uni v3 DEFT/USDC pair and add in DeftStorage
        - create quick v2 DEFT/USDC pair and add in DeftStorage
        - check if pancake DEFT/BUSD pair is created and added to DeftStorage
        - pull liquidity uni v2 DEFT/ETH pair + screenshot
        - pull liquidity pancake v2 DEFT/BNB pair + screenshot
        - deposit 100% ETH to binance.com + screenshot
        - deposit 100% BNB to binance.com + screenshot
        - convert BNB to ETH + screenshot
        - convert 50% ETH to BUSD + screenshot
        - convert 40% ETH to Matic + screenshot
        - convert 10% ETH to USDC + screenshot
        - withdraw BUSD to BSC + screenshot
        - withdraw Matic to Polygon + screenshot
        - withdraw USDC to ETH + screenshot
        - swap Matic for USDC on quick v2 + screenshot
        - add liquidity on uni v3 DEFT/USDC pair + screenshot
        - add liquidity on quick v2 DEFT/USDC pair + screenshot
        - balance price on pancake v2 DEFT/BUSD pair + screenshot
        - add liquidity on pancake v2 DEFT/BUSD pair + screenshot
    */
    
    
    constructor() {
        owner = msg.sender;
    }
    
    receive() external payable {}
    
    modifier isOwner {
        owner == msg.sender;
        _;
    }
    
    uint constant DENORM = 1e18;
    function getPrice()
        public
        view
        returns(uint)
    {
        IUniswapV2Factory iFactory = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS);
        address pairAddr = iFactory.getPair(DEFT_TOKEN_ADDRESS, WETH_TOKEN_ADDRESS);
        
        uint wethBalance = IWeth(WETH_TOKEN_ADDRESS).balanceOf(pairAddr);
        uint deftBalance = IWeth(DEFT_TOKEN_ADDRESS).balanceOf(pairAddr);
        uint initialPrice = (wethBalance * DENORM) / deftBalance;
        return initialPrice;
    }
    
    function migrateDeft(uint amountToMint)
        public
        isOwner
    {
        IDefiFactoryToken iDeft = IDefiFactoryToken(DEFT_TOKEN_ADDRESS);
        
        address[] memory path = new address[](2);
        path[0] = DEFT_TOKEN_ADDRESS;
        path[1] = WETH_TOKEN_ADDRESS;
        
        iDeft.mintHumanAddress(address(this), amountToMint);
        
        iDeft.approve(UNISWAP_V2_ROUTER_ADDRESS, type(uint).max);
        IUniswapV2Router iRouter = IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS);
        
        
        IUniswapV2Factory iFactory = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS);
        address pairAddr = iFactory.getPair(DEFT_TOKEN_ADDRESS, WETH_TOKEN_ADDRESS);
        
        uint initialWethBalance = IWeth(WETH_TOKEN_ADDRESS).balanceOf(pairAddr);
        uint initialDeftBalance = IWeth(DEFT_TOKEN_ADDRESS).balanceOf(pairAddr);
        
        iRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToMint,
            0,
            path,
            owner,
            block.timestamp + 365 days
        );
        uint finalWethBalance = IWeth(WETH_TOKEN_ADDRESS).balanceOf(pairAddr);
        uint finalDeftBalance = IWeth(DEFT_TOKEN_ADDRESS).balanceOf(pairAddr);
        
        uint shouldBeDeftBalance = (initialDeftBalance * finalWethBalance) / initialWethBalance;
        uint amountToBurn = finalDeftBalance - shouldBeDeftBalance;
        
        iDeft.burnHumanAddress(pairAddr, amountToBurn);
        IUniswapV2Pair(pairAddr).sync();
    }
    
}