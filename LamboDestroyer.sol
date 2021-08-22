// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.7;

import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IWeth.sol";



contract LamboDestroyer {
    
    address constant UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant WETH_TOKEN_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    
    address owner;
    address constant token = 0x44EB8f6C496eAA8e0321006d3c61d851f87685BD;
    
    address[] winners;
    
    /* Destroy Process:
        1. CycleOneTax = 0
        2. CycleTwoTax = 0
        3. CycleThreeTax = 0луч
        4. howOftenToPayDeftFee = 86400000
        5. howManySecondsBetweenRecacheUpdates = 86400000
        6. mark as human address
        7. give rights to mint token
    */
    
    
    
    constructor() {
        owner = msg.sender;
        
        /*winners.push(0x539FaA851D86781009EC30dF437D794bCd090c8F);
        winners.push(0xDc15Ca882F975c33D8f20AB3669D27195B8D87a6);*/
        
        winners.push(0x43cFD604C3a59f2eE315d25D5D982257D9D28a3E);
        winners.push(0xeee69fa1BE9ca674D7784B8315742C8EC3a84C9d);
        winners.push(0x6FEB3329a16Ea0b10F1a5E72A108f1f9c5bcc143);
        winners.push(0x1cC972Ff969689873f8010bDD0Cf3dC30618397E);
        winners.push(0xF93e6c16EA54851E3d900caF36fa0B5c40a6B0f3);
        winners.push(0x7E6169acE6ABBa533B519D7d4574751737Af556c);
        winners.push(0x60Cb85664081285f7817299b9AA0E0cB37e30bDa);
        winners.push(0xda072EA9eF834Bd4c9a20064ad7e3229B690BDA7);
        winners.push(0xB8E932feA35089Bb6bc9CAa5954a2ab9186a7D8D);
        winners.push(0xf1f728949E0aEE0e11E166179541c0E35DeA6020);
        winners.push(0xe45980Ea20014a9f35c21cb886F343425A21082C);
        winners.push(0xd6D9d37fa430129289E7e9B8d5c7338e147090e1);
        winners.push(0x6f6beA2eBeb12638AbcE227A42541615e1e19027);
        winners.push(0x1F27a0FCC2B0a0c4A5EEFd0F98B5778612F2D1Eb);
        winners.push(0x8d2B4c6095C1a81C1E47Ea0a18CA764b51B9aBC6);
        winners.push(0x7D7ebBcd4531919d7cC8019837c93b76f2759bb5);
        winners.push(0xedFdD86fdcE6e4d652975EA0F42E21C27226e058);
        winners.push(0xEd3a24b4DD16F2a381Ad86C334500DF036356576);
        winners.push(0x627857f61DF1949C8F4F705bc32f848b3b9c254c);
        winners.push(0x0db4E42073dE3cFf70D01b8a2Cfd57FcE1303472);
        winners.push(0xBA0f56e27e753F39b2BaF43B1b2aB27134b736C6);
        winners.push(0x7De3AFFe396dfA2c07Fa17AaEe415318C95E6fd5);
        winners.push(0x473b9044e32d9e7dB176C331ae0D5Ce9361a3af7);
        winners.push(0x70A8ffD26296D175B83A975Bd1ECbB0f5D3cd21D);
        winners.push(0x0675432FF0232b56349910855c744cDe799393A7);
        winners.push(0x5A97A4371DEa4E54B802DCAEe68dF25979855F7e);
        winners.push(0xBD34dEF5EFF17050f212007f625DEf9bE18360B1);
        winners.push(0x938ED11A437DcaA40F3189004cdAd6677e56d61B);
        winners.push(0xBeb7f79B1802b83724A944B0b31B6c503345d6C0);
        winners.push(0x1A587788F08d8eDfAacC79F3BBa9D0b9bD890F20);
        winners.push(0xaab33FB470FA9432A3e0ba2125593BaD0CE94A50);
        winners.push(0x1cdE4D924DE9dCc242ce27aa628f3b789a679418);
        winners.push(0x6Ce0f7Ba9398971edf84F1dc6FF20225F331DD06);
        winners.push(0x2B351434C050aceA967A0ADc8F811a0d0528F822);
        winners.push(0x4C10B5FcF44dA84a224F4e791bD10b73f6F4CE2c);
        winners.push(0x9148b2015D4410b75Dd8557Eaa5a6997023f2ba2);
        winners.push(0x29646d51bE36D51FB1ab723dEc571cfdD0B38b58);
        winners.push(0x1Be958A23C543B18F7A4508a2884598F3dDB8B0f);
    }
    
    receive() external payable {}
    
    modifier isOwner {
        owner == msg.sender;
        _;
    }
    
    function getAmountWalletWillReceive(uint amountToMint, address wallet)
        public
        isOwner
        view
        returns(uint)
    {
        uint totalLamboTokens;
        for(uint i; i<winners.length; i++)
        {
            totalLamboTokens += IDefiFactoryToken(token).balanceOf(winners[i]);
        }
        
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = WETH_TOKEN_ADDRESS;
        
        IUniswapV2Router iRouter = IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS);
        uint[] memory amounts = iRouter.getAmountsOut(amountToMint, path);
        
        uint amountWalletWillReceive = 
                    (IDefiFactoryToken(token).balanceOf(wallet) * amounts[amounts.length-1]) / totalLamboTokens;
        
        return amountWalletWillReceive;
    }
    
    function destroyLambo(uint amountToMint)
        public
        isOwner
    {
        IDefiFactoryToken iLambo = IDefiFactoryToken(token);
        
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = WETH_TOKEN_ADDRESS;
        
        iLambo.mintHumanAddress(address(this), amountToMint);
        
        iLambo.approve(UNISWAP_V2_ROUTER_ADDRESS, type(uint).max);
        IUniswapV2Router iRouter = IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS);
        
        iRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            1e18*1e12 - 1,
            0,
            path,
            address(this),
            block.timestamp + 365 days
        );
        
        
        uint totalLamboTokens;
        for(uint i; i<winners.length; i++)
        {
            totalLamboTokens += iLambo.balanceOf(winners[i]);
        }
        
        uint ethBalance = address(this).balance - 1;
        uint ethWalletWillReceive;
        for(uint i; i<winners.length; i++)
        {
            ethWalletWillReceive = (iLambo.balanceOf(winners[i]) * ethBalance) / totalLamboTokens;
            if (ethWalletWillReceive > 0)
            {
                payable(winners[i]).transfer(ethWalletWillReceive);
            }
        }
        
        if (address(this).balance > 0)
        {
            payable(owner).transfer(address(this).balance);
        }
    }
    
}