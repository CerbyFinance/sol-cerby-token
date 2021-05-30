// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.0;

import "../interfaces/IDefiFactoryToken.sol";
import "../interfaces/INoBotsTech.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IWeth.sol";
import "../openzeppelin/access/AccessControlEnumerable.sol";


contract TeamVestingContract is AccessControlEnumerable {
    bytes32 public constant ROLE_WHITELIST = keccak256("ROLE_WHITELIST");
    
    uint constant NOBOTS_TECH_CONTRACT_ID = 0;
    uint constant UNISWAP_V2_FACTORY_CONTRACT_ID = 2;

    struct Investor {
        address addr;
        uint wethValue;
        uint sentValue;
        uint startDelay;
        uint lockFor;
    }
    
    enum States { AcceptingPayments, ReachedGoal, PreparedAddLiqudity, CreatedPair, AddedLiquidity, DistributedTokens }
    States public state;
    
    mapping(address => uint) cachedIndex;
    Investor[] investors;
    uint public totalInvested;
    uint public totalSent;
    
    address public defiFactoryToken;
    
    uint public constant TOTAL_SUPPLY_CAP = 100 * 1e9 * 1e18; // 100B DEFT
    
    uint public percentForTheTeam = 30; // 5% - marketing; 10% - team; 15% - developer
    uint public percentForUniswap = 70; // 70% - to uniswap
    uint constant PERCENT_DENORM = 100;
    
    address public nativeToken;
    
    address public developerAddress;
    uint public developerCap;
    uint public constant DEVELOPER_STARTING_LOCK_DELAY = 0 days;
    uint public constant DEVELOPER_STARTING_LOCK_FOR = 730 days;
    
    address public teamAddress;
    uint public teamCap;
    uint public constant TEAM_STARTING_LOCK_DELAY = 0 days;
    uint public constant TEAM_STARTING_LOCK_FOR = 730 days;
    
    address public marketingAddress;
    uint public marketingCap;
    uint public constant MARKETING_STARTING_LOCK_DELAY = 0;
    uint public constant MARKETING_STARTING_LOCK_FOR = 365 days;
    
    uint public startedLocking;
    address public wethAndTokenPairContract;
    
    
    uint public amountOfTokensForInvestors;
    
    address constant BURN_ADDRESS = address(0x0);
    
    constructor() {
        _setupRole(ROLE_ADMIN, _msgSender());
        state = States.AcceptingPayments;
    }

    receive() external payable {
        require(state == States.AcceptingPayments, "TVC: Accepting payments has been stopped!");
        
        addInvestor(_msgSender(), msg.value);
    }

    function addInvestor(address addr, uint wethValue)
        internal
    {
        uint updMaxInvestAmount;
        uint lockFor;
        uint startDelay;
        if (addr == developerAddress)
        {
            updMaxInvestAmount = developerCap;
            lockFor = DEVELOPER_STARTING_LOCK_FOR;
            startDelay = DEVELOPER_STARTING_LOCK_DELAY;
        } else if (addr == teamAddress)
        {
            updMaxInvestAmount = teamCap;
            lockFor = TEAM_STARTING_LOCK_FOR;
            startDelay = TEAM_STARTING_LOCK_DELAY;
        } else if (addr == marketingAddress) 
        {
            updMaxInvestAmount = marketingCap;
            lockFor = MARKETING_STARTING_LOCK_FOR;
            startDelay = MARKETING_STARTING_LOCK_DELAY;
        } else
        {
            revert("TVC: Only team, dev and marketing addresses allowed!");
        }
        
        if (cachedIndex[addr] == 0)
        {
            investors.push(
                Investor(
                    addr, 
                    wethValue,
                    0,
                    startDelay,
                    lockFor
                )
            );
            cachedIndex[addr] = investors.length;
        } else
        {
            investors[cachedIndex[addr] - 1].wethValue += wethValue;
        }
        require(
            investors[cachedIndex[addr] - 1].wethValue <= updMaxInvestAmount,
            "TVC: Requires Investor max amount less than maxInvestAmount!"
        );
        
        totalInvested += wethValue;
    }
    
    function markGoalAsReachedAndPrepareLiqudity()
        public
        onlyRole(ROLE_ADMIN)
    {
        state = States.ReachedGoal;
        
        prepareAddLiqudity();
    }
    
    function prepareAddLiqudity()
        internal
    {
        require(state == States.ReachedGoal, "TVC: Preparing add liquidity is completed!");
        require(address(this).balance > 0, "TVC: Ether balance must be larger than zero!");
        
        IWeth iWeth = IWeth(nativeToken);
        iWeth.deposit{ value: address(this).balance }();
        
        state = States.PreparedAddLiqudity;
    }
    
    function createPairOnUniswapV2()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.PreparedAddLiqudity, "TVC: Pair is already created!");

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
        iNoBotsTech.grantRole(ROLE_WHITELIST, wethAndTokenPairContract);
        
        state = States.CreatedPair;
    }
    
    function addLiquidityOnUniswapV2()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.CreatedPair, "TVC: Liquidity is already added!");
        
        IWeth iWeth = IWeth(nativeToken);
        uint wethAmount = iWeth.balanceOf(address(this));
        iWeth.transfer(wethAndTokenPairContract, wethAmount);
        
        uint amountOfTokensForUniswap = (TOTAL_SUPPLY_CAP * percentForUniswap) / PERCENT_DENORM; // 70% for uniswap
        
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryToken);
        iDefiFactoryToken.mintHumanAddress(wethAndTokenPairContract, amountOfTokensForUniswap);
        
        IUniswapV2Pair iPair = IUniswapV2Pair(wethAndTokenPairContract);
        iPair.mint(_msgSender());
    
        state = States.AddedLiquidity;
        
        distributeTokens();
    }

    function distributeTokens()
        internal
    {
        require(state == States.AddedLiquidity, "TVC: Tokens have already been distributed!");
        
        INoBotsTech iNoBotsTech = INoBotsTech(
            IDefiFactoryToken(defiFactoryToken).
                getUtilsContractAtPos(NOBOTS_TECH_CONTRACT_ID)
        );
        
        iNoBotsTech.grantRole(ROLE_WHITELIST, address(this));
        
        amountOfTokensForInvestors = (TOTAL_SUPPLY_CAP * percentForTheTeam) / PERCENT_DENORM; // 30% for the team
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryToken);
        iDefiFactoryToken.mintHumanAddress(address(this), amountOfTokensForInvestors);
        
        startedLocking = block.timestamp;
        
        state = States.DistributedTokens;
    }
    
    function claimTeamVestingTokens(uint amount)
        public
    {
        address addr = _msgSender();
        
        uint claimableAmount = getClaimableTokenAmount(addr);
        require(claimableAmount > 0, "TVC: !claimable_amount");
        
        if (
            amount == 0 || 
            amount > claimableAmount
        ) {
            amount = claimableAmount;
        }
        
        investors[cachedIndex[addr] - 1].sentValue += amount;
        
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryToken);
        iDefiFactoryToken.transferFromTeamVestingContract(addr, amount);
    }
    
    function burnVestingTokens(uint amount)
        public
        onlyRole(ROLE_ADMIN)
    {
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryToken);
        iDefiFactoryToken.burnHumanAddress(address(this), amount);
        
        amountOfTokensForInvestors -= amount;
    }
    
    function taxVestingTokens(uint amount)
        public
        onlyRole(ROLE_ADMIN)
    {
        INoBotsTech iNoBotsTech = INoBotsTech(
            IDefiFactoryToken(defiFactoryToken).
                getUtilsContractAtPos(NOBOTS_TECH_CONTRACT_ID)
        );
        
        amountOfTokensForInvestors = iNoBotsTech.chargeCustomTaxTeamVestingContract(
            amount, 
            amountOfTokensForInvestors
        );
    }
    
    function getClaimableTokenAmount(address addr)
        public
        view
        returns(uint)
    {
        require(state == States.DistributedTokens, "TVC: Tokens aren't distributed yet!");
        
        require(cachedIndex[addr] > 0, "TVC: !exist");
        
        Investor memory investor = investors[cachedIndex[addr] - 1];
        
        uint realStartedLocking = startedLocking + investor.startDelay;
        if (block.timestamp < realStartedLocking) return 0;
        
        uint lockedUntil = realStartedLocking + investor.lockFor; 
        uint nominator = 1;
        uint denominator = 1;
        if (block.timestamp < lockedUntil)
        {
            nominator = block.timestamp - realStartedLocking;
            denominator = investor.lockFor;
        }
            
        uint claimableAmount = 
            (investor.wethValue * amountOfTokensForInvestors * nominator) / 
                (denominator * totalInvested);
                
        if (claimableAmount <= investor.sentValue) return 0;
        claimableAmount -= investor.sentValue;
        
        return claimableAmount;
    }
    
    function getLeftTokenAmount(address addr)
        public
        view
        returns(uint)
    {
        require(state == States.DistributedTokens, "TVC: Tokens aren't distributed yet!");
        
        Investor memory investor = investors[cachedIndex[addr] - 1];
        uint leftAmount = 
            (investor.wethValue * amountOfTokensForInvestors) / 
                (totalInvested);
                
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
    
    function updateInvestmentSettings(
        address _nativeToken, 
        address _developerAddress, uint _developerCap,
        address _teamAddress, uint _teamCap,
        address _marketingAddress, uint _marketingCap
    )
        public
        onlyRole(ROLE_ADMIN)
    {
        nativeToken = _nativeToken;
        developerAddress = _developerAddress;
        developerCap = _developerCap;
        teamAddress = _teamAddress;
        teamCap = _teamCap;
        marketingAddress = _marketingAddress;
        marketingCap = _marketingCap;
    }
}