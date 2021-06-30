// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.4;

import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IWeth.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";


contract PresaleLambo is AccessControlEnumerable {
    
    struct Investor {
        address addr;
        uint wethValue;
        uint sentValue;
    }
    
    enum States { AcceptingPayments, ReachedGoal, PreparedAddLiqudity, CreatedPair, AddedLiquidity, DistributedTokens }
    States public state;
    
    mapping(address => uint) cachedIndex;
    Investor[] investors;
    uint public totalInvestedWeth;
    uint public maxWethCap = 1e15;
    uint public perWalletWethCap = 1e15;
    uint public amountOfDeftForInvestors;
    
    uint public fixedPriceInUsd = 1e12; // 0.000001 usd
    
    address public lamboTokenAddress;
    address public WETH_TOKEN_ADDRESS;
    address public USDT_TOKEN_ADDRESS;
    address public UNISWAP_V2_FACTORY_ADDRESS;
    address public UNISWAP_V2_ROUTER_ADDRESS;
    address public wethAndTokenPairContract;
    
    uint public constant DEFT_DECIMALS = 18;
    uint public constant WETH_DECIMALS = 18;
    uint public USDT_DECIMALS;
    
    address constant BURN_ADDRESS = address(0x0);
    
    event InvestedAmount(address investorAddr, uint investorAmountWeth);
    event StateChanged(States newState);
    
    constructor() payable {
        _setupRole(ROLE_ADMIN, _msgSender());
        
        lamboTokenAddress = 0x01202D4400f0F04631Dea6221cd789D49eBaC147;
        if (block.chainid == 1)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
            USDT_TOKEN_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
            WETH_TOKEN_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
            USDT_DECIMALS = 6;
        } else if (block.chainid == 56)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0xBCfCcbde45cE874adCB698cC183deBcF17952812;
            UNISWAP_V2_ROUTER_ADDRESS = 0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F;
            USDT_TOKEN_ADDRESS = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
            WETH_TOKEN_ADDRESS = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
            USDT_DECIMALS = 18;
        } else if (block.chainid == 42)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
            USDT_TOKEN_ADDRESS = 0x2F375e94FC336Cdec2Dc0cCB5277FE59CBf1cAe5;
            WETH_TOKEN_ADDRESS = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
            USDT_DECIMALS = 6;
        }
        
        changeState(States.AcceptingPayments);
        
        addInvestor(_msgSender(), msg.value);
        //skipSteps();
    }

    receive() external payable {
        require(state == States.AcceptingPayments, "P: Accepting payments has been stopped!");
        
        addInvestor(_msgSender(), msg.value);
        checkIfGoalIsReached();
    }
    
    function updateFixedPriceInUsd(uint _fixedPriceInUsd)
        public
        onlyRole(ROLE_ADMIN)
    {
        fixedPriceInUsd = _fixedPriceInUsd;
    }
    
    function updateCaps(uint _maxWethCap, uint _perWalletWethCap)
        public
        onlyRole(ROLE_ADMIN)
    {
        maxWethCap = _maxWethCap;
        perWalletWethCap = _perWalletWethCap;
    }
    
    function emergencyRefund()
        public
        onlyRole(ROLE_ADMIN)
    {
        IWeth iWeth = IWeth(WETH_TOKEN_ADDRESS);
        uint amount = iWeth.balanceOf(address(this));
        if (amount > 0)
        {
            iWeth.withdraw(amount);
        }
        
        amount = address(this).balance;
        if (amount > 0)
        {
            payable(msg.sender).transfer(amount);
        }
        changeState(States.AcceptingPayments);
    }
    
    function emergencyWithdrawToken(address _token)
        public
        onlyRole(ROLE_ADMIN)
    {
        IWeth iWeth = IWeth(_token);
        uint amount = iWeth.balanceOf(address(this));
        iWeth.transfer(msg.sender, amount);
    }
    
    function getTotalMintedSupply()
        external
        view
        returns (uint)
    {
        return amountOfDeftForInvestors * 2;
    }
    
    function updateDefiFactoryContract(address newContract)
        external
        onlyRole(ROLE_ADMIN)
    {
        lamboTokenAddress = newContract;
    }
    
    function changeState(States newState)
        private
    {
        state = newState;
        emit StateChanged(newState);
    }

    function addInvestor(address addr, uint wethValue)
        internal
    {
        if (cachedIndex[addr] == 0)
        {
            investors.push(
                Investor(
                    addr, 
                    wethValue,
                    0
                )
            );
            cachedIndex[addr] = investors.length;
        } else
        {
            investors[cachedIndex[addr] - 1].wethValue += wethValue;
        }
        totalInvestedWeth += wethValue;
        emit InvestedAmount(addr, wethValue);
        
        require(wethValue <= perWalletWethCap, "P: Investment limit per wallet exceeded");
    }
    
    function skipSteps()
        private
    {
        checkIfGoalIsReached();
        prepareAddLiqudity();
        checkIfPairIsCreated();
        addLiquidityOnUniswapV2();
        distributeTokens(0,10);
    }
    
    function checkIfGoalIsReached()
        public
    {
        require(state == States.AcceptingPayments, "P: Goal is already reached!");
        
        if (totalInvestedWeth >= maxWethCap)
        {
            changeState(States.ReachedGoal);
        }
    }
    
    function markGoalAsReached()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.AcceptingPayments, "P: Goal is already reached!");
        
        changeState(States.ReachedGoal);
    }
    
    function prepareAddLiqudity()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.ReachedGoal, "P: Preparing add liquidity is completed!");
        require(address(this).balance > 0, "P: Ether balance must be larger than zero!");
        
        IWeth iWeth = IWeth(WETH_TOKEN_ADDRESS);
        iWeth.deposit{ value: address(this).balance }();
        
        changeState(States.PreparedAddLiqudity);
    }
    
    function checkIfPairIsCreated()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.PreparedAddLiqudity, "P: Pair is already created!");

        wethAndTokenPairContract = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).
            getPair(lamboTokenAddress, WETH_TOKEN_ADDRESS);
        
        if (wethAndTokenPairContract == BURN_ADDRESS)
        {
            wethAndTokenPairContract = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).
                createPair(lamboTokenAddress, WETH_TOKEN_ADDRESS);
        }
        
        changeState(States.CreatedPair);
    }
    
    function addLiquidityOnUniswapV2()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.CreatedPair, "P: Liquidity is already added!");
        
        address wethAndUsdtPairContract = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).
            getPair(USDT_TOKEN_ADDRESS, WETH_TOKEN_ADDRESS);
        (uint usdtBalance, uint wethBalance1, ) = IUniswapV2Pair(wethAndUsdtPairContract).getReserves();
        if (USDT_TOKEN_ADDRESS > WETH_TOKEN_ADDRESS)
        {
            (usdtBalance, wethBalance1) = (wethBalance1, usdtBalance);
        }
        
        uint amountOfTokensForUniswap = (usdtBalance * totalInvestedWeth * 10**(36-USDT_DECIMALS)) / (fixedPriceInUsd * wethBalance1);
        
        IWeth iWeth = IWeth(WETH_TOKEN_ADDRESS);
        uint wethAmount = iWeth.balanceOf(address(this));
        iWeth.transfer(wethAndTokenPairContract, wethAmount);
        
        amountOfDeftForInvestors += amountOfTokensForUniswap;
        
        IDefiFactoryToken(lamboTokenAddress).mintHumanAddress(wethAndTokenPairContract, amountOfTokensForUniswap);
        
        IUniswapV2Pair iPair = IUniswapV2Pair(wethAndTokenPairContract);
        iPair.mint(_msgSender());
        
        uint dustLeftInContract = IDefiFactoryToken(lamboTokenAddress).balanceOf(address(this));
        if (dustLeftInContract > 0)
        {
            amountOfDeftForInvestors -= dustLeftInContract;
            IDefiFactoryToken(lamboTokenAddress).
                burnHumanAddress(address(this), dustLeftInContract);
        }
    
        changeState(States.AddedLiquidity);
    }

    function distributeTokens(uint offset, uint limit)
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.AddedLiquidity, "P: Tokens have already been distributed!");
        
        uint leftAmount;
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(lamboTokenAddress);
        Investor[] memory investorsList = listInvestors(offset, limit);
        for(uint i = 0; i < investorsList.length; i++)
        {
            leftAmount = 
            (investorsList[i].wethValue * amountOfDeftForInvestors) / 
                (totalInvestedWeth);
                
            if (leftAmount > investorsList[i].sentValue)
            {
                iDefiFactoryToken.mintHumanAddress(
                    investorsList[i].addr, 
                    leftAmount
                );
                investorsList[i].sentValue += leftAmount;
            }
        }
    }
    
    function getLeftTokenAmount(address addr)
        public
        view
        returns(uint)
    {
        require(state == States.DistributedTokens, "P: Tokens aren't distributed yet!");
        
        Investor memory investor = investors[cachedIndex[addr] - 1];
        uint leftAmount = 
            (investor.wethValue * amountOfDeftForInvestors) / 
                (totalInvestedWeth);
                
        if (leftAmount <= investor.sentValue) return 0;
        leftAmount -= investor.sentValue;
        
        return leftAmount;
    }
    
    function getInvestorsCount()
        public
        view
        returns(uint)
    {
        return investors.length;
    }
    
    function getInvestorByAddr(address addr)
        external
        view
        returns(Investor memory)
    {
        return investors[cachedIndex[addr] - 1];
    }
    
    function getInvestorByPos(uint pos)
        external
        view
        returns(Investor memory)
    {
        return investors[pos];
    }
    
    function listInvestors(uint offset, uint limit)
        public
        view
        returns(Investor[] memory)
    {
        uint start = offset;
        uint end = offset + limit;
        end = (end > investors.length)? investors.length: end;
        uint numItems = (end > start)? end - start: 0;
        
        Investor[] memory listOfInvestors = new Investor[](numItems);
        for(uint i = start; i < end; i++)
        {
            listOfInvestors[i - start] = investors[i];
        }
        
        return listOfInvestors;
    }
    
    function sqrt(uint x) 
        private
        pure
        returns (uint y) 
    {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}