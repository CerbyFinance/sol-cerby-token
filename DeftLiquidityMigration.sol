// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.7;

import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IWeth.sol";



contract DeftLiquidityMigration {
    
    address constant UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant WETH_TOKEN_ADDRESS = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
    uint constant DENORM = 1e18;
    
    address owner;
    address constant DEFT_TOKEN_ADDRESS = 0x7A7492a8e888Ca3fe8e31cB2E34872FE0CE5309f;
    
    constructor() {
        owner = msg.sender;
        
    }
    
    receive() external payable {}
    
    modifier isOwner {
        owner == msg.sender;
        _;
    }
    
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
            address(this),
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