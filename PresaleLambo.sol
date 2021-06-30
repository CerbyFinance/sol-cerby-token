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
    
    address public defiFactoryToken = 0x648C608D1cb7b425a89b64D70A646c2295687169;
    address public wethToken = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
    address public usdtToken = 0x2F375e94FC336Cdec2Dc0cCB5277FE59CBf1cAe5;
    address public uniswapFactory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address public uniswapRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public wethAndTokenPairContract;
    
    uint public constant DEFT_DECIMALS = 18;
    uint public constant WETH_DECIMALS = 18;
    
    address constant BURN_ADDRESS = address(0x0);
    
    event InvestedAmount(address investorAddr, uint investorAmountWeth);
    event StateChanged(States newState);
    
    constructor() payable {
        _setupRole(ROLE_ADMIN, _msgSender());
        changeState(States.AcceptingPayments);
        
        addInvestor(_msgSender(), msg.value);
        skipSteps();
    }

    receive() external payable {
        require(state == States.AcceptingPayments, "P: Accepting payments has been stopped!");
        
        addInvestor(_msgSender(), msg.value);
        checkIfGoalIsReached();
    }
    
    // TODO: update contracts values
    // TODO: emergency refund
    // TODO: update max weth cap
    
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
        defiFactoryToken = newContract;
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
    
    function prepareAddLiqudity()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.ReachedGoal, "P: Preparing add liquidity is completed!");
        require(address(this).balance > 0, "P: Ether balance must be larger than zero!");
        
        IWeth iWeth = IWeth(wethToken);
        iWeth.deposit{ value: address(this).balance }();
        
        changeState(States.PreparedAddLiqudity);
    }
    
    function checkIfPairIsCreated()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.PreparedAddLiqudity, "P: Pair is already created!");

        wethAndTokenPairContract = IUniswapV2Factory(uniswapFactory).
            getPair(defiFactoryToken, wethToken);
        
        require(wethAndTokenPairContract != BURN_ADDRESS, "P: Pair does not exist!");
        
        changeState(States.CreatedPair);
    }
    
    function balancePairPrice(uint normedDeftPriceInUSD, uint PRICE_DENORM)
        public
        onlyRole(ROLE_ADMIN)
    {
        address wethAndUsdtPairContract = IUniswapV2Factory(uniswapFactory).
            getPair(usdtToken, wethToken);
        (uint usdtBalance, uint wethBalance1, ) = IUniswapV2Pair(wethAndUsdtPairContract).getReserves();
        if (usdtToken > wethToken)
        {
            (usdtBalance, wethBalance1) = (wethBalance1, usdtBalance);
        }
        
        (uint deftBalance, uint wethBalance2, ) = IUniswapV2Pair(wethAndTokenPairContract).getReserves();
        if (defiFactoryToken > wethToken)
        {
            (deftBalance, wethBalance2) = (wethBalance2, deftBalance);
        }
        
        uint shouldBeNormedDeftPriceInWeth = 
            (normedDeftPriceInUSD * wethBalance1) / (usdtBalance * 10**(WETH_DECIMALS - IWeth(usdtToken).decimals()));
        uint sqrt1 = sqrt(
                            (PRICE_DENORM * wethBalance2) / 
                                (deftBalance * shouldBeNormedDeftPriceInWeth)
                        );
        uint sqrt2 = sqrt(
                            (PRICE_DENORM * deftBalance * shouldBeNormedDeftPriceInWeth) / 
                                (wethBalance2)
                        );
        if (sqrt1 > PRICE_DENORM)
        {
            // sell deft
            uint amountOfDeftToSell =
                (deftBalance * 1000 * (sqrt1 - PRICE_DENORM)) / (997 * PRICE_DENORM);
            
            //IDefiFactoryToken(defiFactoryToken).mintHumanAddress(address(this), amountOfDeftToSell);
            IDefiFactoryToken(defiFactoryToken).mintByBridge(address(this), amountOfDeftToSell);
            amountOfDeftForInvestors += amountOfDeftToSell;
            
            address[] memory path = new address[](2);
            path[0] = defiFactoryToken;
            path[1] = wethToken;
            
            IWeth(defiFactoryToken).approve(uniswapRouter, type(uint).max);
            IUniswapV2Router(uniswapRouter).swapExactTokensForTokens(
                amountOfDeftToSell,
                0, 
                path, 
                address(this),
                block.timestamp + 864000
            );
        } else if (sqrt2 > PRICE_DENORM)
        {
            // buy deft
            uint amountOfWethToBuy =
                (wethBalance2 * 1000 * (sqrt2 - PRICE_DENORM)) / (997 * PRICE_DENORM);
            
            address[] memory path = new address[](2);
            path[0] = wethToken;
            path[1] = defiFactoryToken;
            
            IWeth(wethToken).approve(uniswapRouter, type(uint).max);
            IUniswapV2Router(uniswapRouter).swapExactTokensForTokens(
                amountOfWethToBuy,
                0, 
                path, 
                address(this),
                block.timestamp + 864000
            );
        }
    }
    
    function addLiquidityOnUniswapV2()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.CreatedPair, "P: Liquidity is already added!");
        
        (uint deftBalance, uint wethBalance2, ) = IUniswapV2Pair(wethAndTokenPairContract).getReserves();
        if (defiFactoryToken > wethToken)
        {
            (deftBalance, wethBalance2) = (wethBalance2, deftBalance);
        }
        
        IWeth iWeth = IWeth(wethToken);
        uint wethAmount = iWeth.balanceOf(address(this));
        iWeth.transfer(wethAndTokenPairContract, wethAmount);
        
        uint amountOfTokensForUniswap = (deftBalance * wethAmount) / wethBalance2;
        amountOfDeftForInvestors += amountOfTokensForUniswap;
        
        //IDefiFactoryToken(defiFactoryToken).mintHumanAddress(wethAndTokenPairContract, amountOfTokensForUniswap);
        IDefiFactoryToken(defiFactoryToken).mintByBridge(wethAndTokenPairContract, amountOfTokensForUniswap);
        
        IUniswapV2Pair iPair = IUniswapV2Pair(wethAndTokenPairContract);
        iPair.mint(_msgSender());
        
        amountOfDeftForInvestors -= IDefiFactoryToken(defiFactoryToken).balanceOf(address(this));
        IDefiFactoryToken(defiFactoryToken).
            burnByBridge(address(this), IDefiFactoryToken(defiFactoryToken).balanceOf(address(this)));
    
        changeState(States.AddedLiquidity);
    }

    function distributeTokens(uint offset, uint limit)
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.AddedLiquidity, "P: Tokens have already been distributed!");
        
        uint leftAmount;
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryToken);
        Investor[] memory investorsList = listInvestors(offset, limit);
        for(uint i = 0; i < investorsList.length; i++)
        {
            leftAmount = 
            (investorsList[i].wethValue * amountOfDeftForInvestors) / 
                (totalInvestedWeth);
                
            if (leftAmount > investorsList[i].sentValue)
            {
                iDefiFactoryToken.mintByBridge(
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