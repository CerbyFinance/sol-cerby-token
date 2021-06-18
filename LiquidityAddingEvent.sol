// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.4;

import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IWeth.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";


contract LiquidityAddingEvent is AccessControlEnumerable {
    
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
    
    address public defiFactoryToken = 0x648C608D1cb7b425a89b64D70A646c2295687169;
    address public wethToken = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
    address public wethAndTokenPairContract = 0x4E22bbbBd75bcB9D5A40604D29fE3178A3D9E4D2;
    address public uniswapFactory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    
    uint public constant TOTAL_SUPPLY_CAP = 10e9 * 1e18; // 10B DEFT
    
    uint public percentForUniswap = 50; // 50% - to pancakeswap
    uint constant PERCENT_DENORM = 100;
    
    uint public amountOfTokensForInvestors;
    
    address constant BURN_ADDRESS = address(0x0);
    
    constructor() {
        _setupRole(ROLE_ADMIN, _msgSender());
        state = States.AcceptingPayments;
    }

    receive() external payable {
        require(state == States.AcceptingPayments, "LEA: Accepting payments has been stopped!");
        
        addInvestor(_msgSender(), msg.value);
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
            totalInvestedWeth += wethValue;
        }
        
        checkIfGoalIsReached();
    }
    
    function checkIfGoalIsReached()
        public
    {
        require(state == States.AcceptingPayments, "LEA: Goal is already reached!");
        
        if (totalInvestedWeth >= maxWethCap)
        {
            state = States.ReachedGoal;
        }
    }
    
    function prepareAddLiqudity()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.ReachedGoal, "LEA: Preparing add liquidity is completed!");
        require(address(this).balance > 0, "LEA: Ether balance must be larger than zero!");
        
        IWeth iWeth = IWeth(defiFactoryToken);
        iWeth.deposit{ value: address(this).balance }();
        
        state = States.PreparedAddLiqudity;
    }
    
    function checkIfPairIsCreated()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.PreparedAddLiqudity, "LEA: Pair is already created!");

        wethAndTokenPairContract = IUniswapV2Factory(uniswapFactory).
            getPair(defiFactoryToken, wethToken);
        
        require(wethAndTokenPairContract != BURN_ADDRESS, "LEA: Pair does not exist!");
        
        state = States.CreatedPair;
    }
    
    function addLiquidityOnUniswapV2()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.CreatedPair, "LEA: Liquidity is already added!");
        
        IWeth iWeth = IWeth(defiFactoryToken);
        uint wethAmount = iWeth.balanceOf(address(this));
        iWeth.transfer(wethAndTokenPairContract, wethAmount);
        
        uint amountOfTokensForUniswap = (TOTAL_SUPPLY_CAP * percentForUniswap) / PERCENT_DENORM; // 50% for uniswap
        
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryToken);
        iDefiFactoryToken.mintHumanAddress(wethAndTokenPairContract, amountOfTokensForUniswap);
        
        IUniswapV2Pair iPair = IUniswapV2Pair(wethAndTokenPairContract);
        iPair.mint(_msgSender());
    
        state = States.AddedLiquidity;
    }

    function distributeTokens()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.AddedLiquidity, "LEA: Tokens have already been distributed!");
        
        
        amountOfTokensForInvestors = (TOTAL_SUPPLY_CAP * (PERCENT_DENORM - percentForUniswap)) / PERCENT_DENORM; // 50% for the investors
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryToken);
        iDefiFactoryToken.mintHumanAddress(address(this), amountOfTokensForInvestors);
        
        
        state = States.DistributedTokens;
    }
    
    
    function getLeftTokenAmount(address addr)
        public
        view
        returns(uint)
    {
        require(state == States.DistributedTokens, "LEA: Tokens aren't distributed yet!");
        
        Investor memory investor = investors[cachedIndex[addr] - 1];
        uint leftAmount = 
            (investor.wethValue * amountOfTokensForInvestors) / 
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
    
    function updateDefiFactoryContract(address newContract)
        external
        onlyRole(ROLE_ADMIN)
    {
        defiFactoryToken = newContract;
    }
}