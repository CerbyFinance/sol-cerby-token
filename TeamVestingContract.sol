// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IDefiFactoryToken.sol";
import "./INoBotsTech.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV3Factory.sol";
import "./IUniswapV3Pool.sol";
import "./IWeth.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";


contract TeamVestingContract is AccessControlEnumerable {
    bytes32 public constant ROLE_WHITELIST = keccak256("ROLE_WHITELIST");
    bytes32 public constant ROLE_NOTAX = keccak256("ROLE_NOTAX");
    
    uint constant NOBOTS_TECH_CONTRACT_ID = 0;
    uint constant UNISWAP_V2_FACTORY_CONTRACT_ID = 2;
    uint constant UNISWAP_V3_FACTORY_CONTRACT_ID = 3;

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
    
    address public defiFactoryToken = 0x2493e2D8a80d95AF4e4d2C1448a29c34Ba27ca30;
    
    uint public constant TOTAL_SUPPLY_CAP = 100 * 1e9 * 1e18; // 100B
    
    uint public percentForTheTeam = 30;
    uint public percentForUniswap = 70;
    uint constant PERCENT_DENORM = 100;
    
    address public nativeToken;
    
    address public developerAddress;
    uint public developerCap = 150e13;
    uint public constant DEVELOPER_STARTING_LOCK_DELAY = 0 days;
    uint public constant DEVELOPER_STARTING_LOCK_FOR = 10 minutes; // TODO: Change on production
    
    address public teamAddress;
    uint public teamCap = 100e13;
    uint public constant TEAM_STARTING_LOCK_DELAY = 0 days;
    uint public constant TEAM_STARTING_LOCK_FOR = 730 days;
    
    address public marketingAddress;
    uint public marketingCap = 50e13;
    uint public constant MARKETING_STARTING_LOCK_DELAY = 0;
    uint public constant MARKETING_STARTING_LOCK_FOR = 365;
    
    uint public startedLocking;
    address public wethAndTokenPairContract;
    
    uint24 constant UNISWAP_V3_FEE = 3000;
    
    uint amountOfTokensForInvestors;
    
    address constant BURN_ADDRESS = address(0x0);
    
    constructor () payable {
        
        _setupRole(ROLE_ADMIN, _msgSender());
        
        // TODO: remove on production
        updateInvestmentSettings(
            0xd0A1E359811322d97991E03f863a0C30C2cF029C, // WETH kovan
            0x539FaA851D86781009EC30dF437D794bCd090c8F, 150e13, // dev
            0xDc15Ca882F975c33D8f20AB3669D27195B8D87a6, 100e13, // team
            0xE019B37896f129354cf0b8f1Cf33936b86913A34, 50e13 // marketing
        );
        
        state = States.AcceptingPayments;
        
        // TODO: remove on production
        addInvestor(msg.sender, msg.value);
        checkIfGoalIsReached();
        prepareAddLiqudity();
    }

    receive() external payable {
        require(state == States.AcceptingPayments, "VestingContract: Accepting payments has been stopped!");
        
        addInvestor(msg.sender, msg.value);
    }
    
    modifier onlyAdmins {
        require(hasRole(ROLE_ADMIN, _msgSender()), "VestingContract: !ROLE_ADMIN");
        _;
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
            updMaxInvestAmount = 0;
            lockFor = 36500 days;
            startDelay = 36500 days;
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
            "VestingContract: Requires Investor max amount less than maxInvestAmount!"
        );
        
        totalInvested += wethValue;
    }
    
    function checkIfGoalIsReached()
        public
        onlyAdmins
    {
        state = States.ReachedGoal;
    }
    
    function prepareAddLiqudity()
        public
        onlyAdmins
    {
        require(state == States.ReachedGoal, "VestingContract: Preparing add liquidity is completed!");
        require(address(this).balance > 0, "VestingContract: Ether balance must be larger than zero!");
        
        IWeth iWeth = IWeth(nativeToken);
        iWeth.deposit{ value: address(this).balance }();
        
        state = States.PreparedAddLiqudity;
    }
    
    function createPair(bool isV2)
        public
        onlyAdmins
    {
        require(state == States.PreparedAddLiqudity, "VestingContract: Pair is already created!");

        if (isV2)
        {
            IUniswapV2Factory iUniswapV2Factory = IUniswapV2Factory(
                IDefiFactoryToken(defiFactoryToken).
                    getUtilsContractAtPos(UNISWAP_V2_FACTORY_CONTRACT_ID)
            );
            wethAndTokenPairContract = iUniswapV2Factory.getPair(defiFactoryToken, nativeToken);
            if (wethAndTokenPairContract == BURN_ADDRESS)
            {
                wethAndTokenPairContract = iUniswapV2Factory.createPair(defiFactoryToken, nativeToken);
            }
        } else {
            IUniswapV3Factory iUniswapV3Factory = IUniswapV3Factory(
                IDefiFactoryToken(defiFactoryToken).
                    getUtilsContractAtPos(UNISWAP_V3_FACTORY_CONTRACT_ID)
            );
            
            wethAndTokenPairContract = iUniswapV3Factory.getPool(defiFactoryToken, nativeToken, UNISWAP_V3_FEE);
            if (wethAndTokenPairContract == BURN_ADDRESS)
            {
                wethAndTokenPairContract = iUniswapV3Factory.createPool(defiFactoryToken, nativeToken, UNISWAP_V3_FEE);
            }
        }
           
        INoBotsTech iNoBotsTech = INoBotsTech(
            IDefiFactoryToken(defiFactoryToken).
                getUtilsContractAtPos(NOBOTS_TECH_CONTRACT_ID)
        ); 
        iNoBotsTech.grantRole(ROLE_WHITELIST, wethAndTokenPairContract);
        
        state = States.CreatedPair;
        
        addLiquidity(isV2);
    }
    
    function addLiquidity(bool isV2)
        public
        onlyAdmins
    {
        require(state == States.CreatedPair, "VestingContract: Liquidity is already added!");
        
        IWeth iWeth = IWeth(nativeToken);
        uint wethAmount = iWeth.balanceOf(address(this));
        iWeth.transfer(wethAndTokenPairContract, wethAmount);
        
        uint amountOfTokensForUniswap = (TOTAL_SUPPLY_CAP * percentForUniswap) / PERCENT_DENORM; // 70% for uniswap
        
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryToken);
        iDefiFactoryToken.mintHumanAddress(wethAndTokenPairContract, amountOfTokensForUniswap);
        
        if (isV2)
        {
            IUniswapV2Pair iPair = IUniswapV2Pair(wethAndTokenPairContract);
            iPair.mint(_msgSender());
        } else
        {
            IUniswapV3Pool iPool = IUniswapV3Pool(wethAndTokenPairContract);
            // TODO: figure out
        }
    
        state = States.AddedLiquidity;
        
        distributeTokens();
    }

    function distributeTokens()
        public
        onlyAdmins
    {
        require(state == States.AddedLiquidity, "VestingContract: Tokens have already been distributed!");
        
        INoBotsTech iNoBotsTech = INoBotsTech(
            IDefiFactoryToken(defiFactoryToken).
                getUtilsContractAtPos(NOBOTS_TECH_CONTRACT_ID)
        );
        
        iNoBotsTech.grantRole(ROLE_WHITELIST, address(this));
        iNoBotsTech.grantRole(ROLE_NOTAX, address(this));
        
        amountOfTokensForInvestors = (TOTAL_SUPPLY_CAP * percentForTheTeam) / PERCENT_DENORM; // 30% for the team
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryToken);
        iDefiFactoryToken.mintHumanAddress(address(this), amountOfTokensForInvestors);
        
        startedLocking = block.timestamp;
        
        state = States.DistributedTokens;
    }
    
    function claimTeamVestingTokens(uint amount)
        public
    {
        address addr = msg.sender;
        
        uint claimableAmount = getClaimableTokenAmount(addr);
        require(claimableAmount > 0, "VestingContract: !claimable_amount");
        
        if (
            amount == 0 || 
            amount > claimableAmount
        ) {
            amount = claimableAmount;
        }
        require(amount <= claimableAmount, "VestingContract: !amount");
        require(cachedIndex[addr] > 0, "VestingContract: !exists_addr");
        
        investors[cachedIndex[addr] - 1].sentValue += amount;
        
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryToken);
        iDefiFactoryToken.transferFromTeamVestingContract(addr, amount);
    }
    
    function burnVestingTokens(uint amount)
        public
        onlyAdmins
    {
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryToken);
        iDefiFactoryToken.burnHumanAddress(address(this), amount);
        
        INoBotsTech iNoBotsTech = INoBotsTech(
            IDefiFactoryToken(defiFactoryToken).
                getUtilsContractAtPos(NOBOTS_TECH_CONTRACT_ID)
        );
        amountOfTokensForInvestors -= iNoBotsTech.getRealBalanceVestingContract(amount);
    }
    
    function taxVestingTokens(uint amount)
        public
        onlyAdmins
    {
        INoBotsTech iNoBotsTech = INoBotsTech(
            IDefiFactoryToken(defiFactoryToken).
                getUtilsContractAtPos(NOBOTS_TECH_CONTRACT_ID)
        );
        
        amountOfTokensForInvestors = iNoBotsTech.chargeCustomTax(
            amount, 
            amountOfTokensForInvestors
        );
    }
    
    function getClaimableTokenAmount(address addr)
        public
        view
        returns(uint)
    {
        require(state == States.DistributedTokens, "VestingContract: Tokens aren't distributed yet!");
        
        require(cachedIndex[addr] > 0, "VestingContract: !exist");
        
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
        require(state == States.DistributedTokens, "VestingContract: Tokens aren't distributed yet!");
        
        if (addr == BURN_ADDRESS) addr = msg.sender;
        Investor memory investor = investors[cachedIndex[msg.sender] - 1];
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
        onlyAdmins
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
        onlyAdmins
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