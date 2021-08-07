// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.4;

import "./interfaces/ITeamFinance.sol";
import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IWeth.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";

/*
TODO: Plan on presale contract
+ rename all Lambo references
+ rename all Deft references
+ add referrals tracking to enumerable set
+ get referral earnings function
+ add referral program
+ add invest function
+ output total investment stats
+ output per investor stats
+ output limits, caps
+ distribute referral tokens
+ debug contract
- add custom tokenomics
- add token vesting schedule
*/


contract PresaleContract is AccessControlEnumerable {
    
    struct Investor {
        address investorAddr;
        address referralAddr;
        
        uint wethValue;
    }
    
    struct Referral {
        address referralAddr;
        
        uint earnings;
    }
    
    struct Tokenomics {
        address tokenomicsAddr;
        string tokenomicsName;
        uint tokenomicsPercentage;
        uint tokenomicsLockedForXSeconds;
        uint tokenomicsVestedForXSeconds;
    }
    
    struct Vesting {
        address vestingAddr;
        uint tokensReserved;
        uint tokensSent;
        uint lockedForXSeconds;
        uint vestedForXSeconds;
    }
    
    
    enum States { 
        AcceptingPayments, 
        ReachedGoal, 
        PreparedAddLiqudity, 
        CreatedPair, 
        AddedLiquidity, 
        SetVestingForTokenomicsTokens, 
        SetVestingForInvestorsTokens, 
        SetVestingForReferralsTokens
    }
    States public state;
    
    mapping(address => uint) public cachedIndexInvestors;
    Investor[] public investors;
    
    mapping(address => uint) public cachedIndexVesting;
    Vesting[] public vesting;
    
    mapping(address => uint) public cachedIndexReferrals;
    Referral[] public referrals;
    
    mapping(address => uint) public cachedIndexTokenomics;
    Tokenomics[] public tokenomics;
    
    uint public refPercent = 5e4; // 5%
    uint constant PERCENT_DENORM = 1e6;
    
    uint totalInvestedWeth;
    uint maxWethCap = 5e18;
    uint perWalletMinWeth = 1e10;
    uint perWalletMaxWeth = 50e20;
    
    uint public amountOfTokensForInvestors;
    uint public totalTokenSupply;
    
    uint public fixedPriceInUsd = 1e12; // 1e-6 usd
    
    address public tokenAddress;
    address public TEAM_FINANCE_ADDRESS;
    address public WETH_TOKEN_ADDRESS;
    address public USDT_TOKEN_ADDRESS;
    address public UNISWAP_V2_FACTORY_ADDRESS;
    address public UNISWAP_V2_ROUTER_ADDRESS;
    address public wethAndTokenPairContract;
    
    uint constant ETH_MAINNET_CHAIN_ID = 1;
    uint constant ETH_ROPSTEN_CHAIN_ID = 3;
    uint constant ETH_KOVAN_CHAIN_ID = 42;
    uint constant BSC_MAINNET_CHAIN_ID = 56;
    uint constant BSC_TESTNET_CHAIN_ID = 97;
    
    uint constant TOKEN_DECIMALS = 18;
    uint constant WETH_DECIMALS = 18;
    uint USDT_DECIMALS;
    
    address constant DEFAULT_REFERRAL_ADDRESS = 0xC427a912E0B19f082840A0045E430dE5b8cB1f65;
    
    address public constant BURN_ADDRESS = address(0x0);
    
    string public website;
    string public telegram;
    
    string public presaleName;
    uint public uniswapLiquidityLockedFor;
    uint public presaleLockedFor;
    uint public presaleVestedFor;
    uint public referralsLockedFor;
    uint public referralsVestedFor;
    
    event StateChanged(States newState);
    
    /* Referral wallet for tests: 0xDc15Ca882F975c33D8f20AB3669D27195B8D87a6 */
    
    constructor() {
        _setupRole(ROLE_ADMIN, _msgSender());
        
        presaleName = "Lambo Token Presale";
        website = "https://lambo.defifactory.finance";
        telegram = "https://t.me/LamboTokenOwners";
        
        uniswapLiquidityLockedFor = 36500 days;
        presaleLockedFor = 1 days;
        presaleVestedFor = 7 days;
        referralsLockedFor = 1 days;
        referralsVestedFor = 7 days;
        
        addTokenomics(
            0x1111BEe701Ef814A2B6A3EDD4B1652cB9cc5aA6f,
            "Development",
            15e4,
            1 minutes,
            10 minutes
        );
        addTokenomics(
            0x2222bEE701Ef814a2B6a3edD4B1652cB9Cc5Aa6F,
            "Marketing",
            10e4,
            2 minutes,
            20 minutes
        );
        addTokenomics(
            0x3333BeE701EF814A2b6a3edD4B1652cb9Cc5AA6F,
            "Advisors",
            5e4,
            3 minutes,
            30 minutes
        );
        
        if (block.chainid == ETH_MAINNET_CHAIN_ID)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
            USDT_TOKEN_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
            WETH_TOKEN_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
            USDT_DECIMALS = 6;
            TEAM_FINANCE_ADDRESS = 0xC77aab3c6D7dAb46248F3CC3033C856171878BD5;
        } else if (block.chainid == BSC_MAINNET_CHAIN_ID)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
            UNISWAP_V2_ROUTER_ADDRESS = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
            USDT_TOKEN_ADDRESS = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
            WETH_TOKEN_ADDRESS = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
            USDT_DECIMALS = 18;
            TEAM_FINANCE_ADDRESS = 0x7536592bb74b5d62eB82e8b93b17eed4eed9A85c;
        } else if (block.chainid == ETH_KOVAN_CHAIN_ID)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
            USDT_TOKEN_ADDRESS = 0x2F375e94FC336Cdec2Dc0cCB5277FE59CBf1cAe5;
            WETH_TOKEN_ADDRESS = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
            USDT_DECIMALS = 6;
            TEAM_FINANCE_ADDRESS = BURN_ADDRESS;
            
            tokenAddress = 0x94fFFf5EAe20544c00D4709918Ae07D2FB672a52; // TODO: set token address for debug
        } else if (block.chainid == ETH_ROPSTEN_CHAIN_ID)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
            USDT_TOKEN_ADDRESS = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F;
            WETH_TOKEN_ADDRESS = 0xc778417E063141139Fce010982780140Aa0cD5Ab;
            USDT_DECIMALS = 6;
            TEAM_FINANCE_ADDRESS = 0x8733CAA60eDa1597336c0337EfdE27c1335F7530;
        }
        
        changeState(States.AcceptingPayments);
    }

    receive() external payable {
    }
    
    function getUniswapSupplyPercent()
        public
        view
        returns(uint)
    {
        uint totalTeamPercent;
        for(uint i; i<tokenomics.length; i++)
        {
            totalTeamPercent += tokenomics[i].tokenomicsPercentage;
        }
        return (PERCENT_DENORM*(PERCENT_DENORM - totalTeamPercent)) / (2*PERCENT_DENORM + refPercent);
    }
    
    function getTotalInvestmentsStatistics()
        external
        view
        returns(uint, uint)
    {
        return (totalInvestedWeth, maxWethCap);
    }
    
    function getWalletStatistics(address addr)
        external
        view
        returns(uint, uint, uint, uint)
    {
        return (
            investors[cachedIndexInvestors[addr] - 1].wethValue, 
            referrals[cachedIndexReferrals[addr] - 1].earnings,
            perWalletMinWeth, 
            perWalletMaxWeth
        );
    }
    
    function invest(address referralAddr)
        external
        payable
    {
        require(state == States.AcceptingPayments, "PR: Accepting payments has been stopped!");
        require(totalInvestedWeth <= maxWethCap, "PR: Max cap reached!");
        require(msg.value >= perWalletMinWeth, "PR: Amount is below minimum permitted");
        require(msg.value <= perWalletMaxWeth, "PR: Amount is above maximum permitted");
        require(cachedIndexTokenomics[msg.sender]  == 0, "PR: Team is not allowed to invest");
        require(cachedIndexReferrals[referralAddr] == 0, "PR: Please use different referral link");
        require(msg.sender != referralAddr, "PR: Self-ref isn't allowed. Please use different referral link");
        
        if (referralAddr == BURN_ADDRESS)
        {
            referralAddr = DEFAULT_REFERRAL_ADDRESS;
        }
        
        addInvestor(msg.sender, referralAddr, msg.value);
        
        addReferral(
            referralAddr, 
            (msg.value * refPercent) / PERCENT_DENORM
        );
    }

    function addInvestor(address investorAddr, address referralAddr, uint wethValue)
        internal
    {
        if (cachedIndexInvestors[investorAddr] == 0)
        {
            investors.push(
                Investor(
                    investorAddr, 
                    referralAddr, 
                    wethValue
                )
            );
            cachedIndexInvestors[investorAddr] = investors.length;
        } else
        {
            uint updatedWethValue = investors[cachedIndexInvestors[investorAddr] - 1].wethValue + wethValue;
            require(updatedWethValue <= perWalletMaxWeth, "PR: Max cap per wallet exceeded");
            
            investors[cachedIndexInvestors[investorAddr] - 1].wethValue = updatedWethValue;
        }
        totalInvestedWeth += wethValue;
        
        createVestingIfDoesNotExist(
              investorAddr
        );
    }

    function addReferral(address referralAddr, uint earnings)
        internal
    {
        if (cachedIndexReferrals[referralAddr] == 0)
        {
            referrals.push(
                Referral(
                    referralAddr, 
                    earnings
                )
            );
            cachedIndexReferrals[referralAddr] = referrals.length;
        } else
        {
            referrals[cachedIndexReferrals[referralAddr] - 1].earnings += earnings;
        }
        
        createVestingIfDoesNotExist(
              referralAddr
        );
    }
    
    function addTokenomics(
        address tokenomicsAddr,
        string memory tokenomicsName,
        uint tokenomicsPercentage,
        uint tokenomicsLockedForXSeconds,
        uint tokenomicsVestedForXSeconds
    )
        internal
    {
        if (cachedIndexTokenomics[tokenomicsAddr] == 0)
        {
            tokenomics.push(
                Tokenomics(
                    tokenomicsAddr,
                    tokenomicsName,
                    tokenomicsPercentage,
                    tokenomicsLockedForXSeconds,
                    tokenomicsVestedForXSeconds
                )
            );
            cachedIndexTokenomics[tokenomicsAddr] = referrals.length;
        } else
        {
            tokenomics[cachedIndexTokenomics[tokenomicsAddr] - 1].tokenomicsName = tokenomicsName;
            tokenomics[cachedIndexTokenomics[tokenomicsAddr] - 1].tokenomicsPercentage = tokenomicsPercentage;
            tokenomics[cachedIndexTokenomics[tokenomicsAddr] - 1].tokenomicsLockedForXSeconds = tokenomicsLockedForXSeconds;
            tokenomics[cachedIndexTokenomics[tokenomicsAddr] - 1].tokenomicsVestedForXSeconds = tokenomicsVestedForXSeconds;
        }
    }

    function createVestingIfDoesNotExist(
        address vestingAddr
    )
        internal
    {
        if (cachedIndexVesting[vestingAddr] == 0)
        {
            vesting.push(
                Vesting(
                    vestingAddr,
                    1,
                    1,
                    1,
                    1
                )
            );
            cachedIndexVesting[vestingAddr] = vesting.length;
        }
    }

    function updateTokenomics(Tokenomics[] calldata _tokenomics)
        public
        onlyRole(ROLE_ADMIN)
    {
        // TODO: only during investment state
        
        delete tokenomics;
        for(uint i; i<_tokenomics.length; i++)
        {
            tokenomics.push(_tokenomics[i]);
        }
    }
    
    function getTokenomics()
        public
        view
        returns(Tokenomics[] memory)
    {
        uint uniswapSupplyPercent = getUniswapSupplyPercent();
        Tokenomics[] memory output = new Tokenomics[](3 + tokenomics.length);
        output[0] = Tokenomics(
            address(0x1),
            "Liquidity",
            uniswapSupplyPercent,
            uniswapLiquidityLockedFor,
            0
        );
        output[1] = Tokenomics(
            address(0x2),
            "Presale",
            uniswapSupplyPercent,
            presaleLockedFor,
            presaleVestedFor
        );
        output[2] = Tokenomics(
            address(0x3),
            "Referrals",
            (uniswapSupplyPercent * refPercent) / PERCENT_DENORM,
            referralsLockedFor,
            referralsVestedFor
        );
        
        for(uint i; i<tokenomics.length; i++)
        {
            output[i + 3] = tokenomics[i];
        }
        return (tokenomics);
    }
    
    function updateRefPercent(uint _value)
        public
        onlyRole(ROLE_ADMIN)
    {
        refPercent = _value;
    }
    
    function updateFixedPriceInUsd(uint _value)
        public
        onlyRole(ROLE_ADMIN)
    {
        fixedPriceInUsd = _value;
    }
    
    function updateCaps(uint _maxWethCap, uint _perWalletMinWeth, uint _perWalletMaxWeth)
        public
        onlyRole(ROLE_ADMIN)
    {
        maxWethCap = _maxWethCap;
        perWalletMinWeth = _perWalletMinWeth;
        perWalletMaxWeth = _perWalletMaxWeth;
    }
    
    function updateTokenContract(address _value)
        public
        onlyRole(ROLE_ADMIN)
    {
        tokenAddress = _value;
    }
    
    function changeState(States _value)
        private
    {
        state = _value;
        emit StateChanged(_value);
    }
    
    function skipSteps1()
        public
    {
        markGoalAsReached();
        prepareAddLiqudity();
        checkIfPairIsCreated();
    }
    
    function skipSteps2(uint limit)
        public
    {
        addLiquidityOnUniswapV2();
        
        setVestingForTokenomicsTokens();
        
        limit = limit == 0? investors.length: limit;
        setVestingForInvestorsTokens(0, limit);
        
        limit = limit == 0? investors.length: limit;
        setVestingForReferralsTokens(0, limit);
    }
    
    function markGoalAsReached()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.AcceptingPayments, "PR: Goal is already reached!");
        
        changeState(States.ReachedGoal);
    }
    
    function prepareAddLiqudity()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.ReachedGoal, "PR: Preparing add liquidity is completed!");
        require(address(this).balance > 0, "PR: Ether balance must be larger than zero!");
        
        IWeth iWeth = IWeth(WETH_TOKEN_ADDRESS);
        iWeth.deposit{ value: address(this).balance }();
        
        changeState(States.PreparedAddLiqudity);
    }
    
    function checkIfPairIsCreated()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.PreparedAddLiqudity, "PR: Pair is already created!");
        require(tokenAddress != BURN_ADDRESS, "PR: Token address was not initialized yet!");

        wethAndTokenPairContract = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).
            getPair(tokenAddress, WETH_TOKEN_ADDRESS);
        
        if (wethAndTokenPairContract == BURN_ADDRESS)
        {
            wethAndTokenPairContract = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).
                createPair(tokenAddress, WETH_TOKEN_ADDRESS);
        }
        
        changeState(States.CreatedPair);
    }
    
    function addLiquidityOnUniswapV2()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.CreatedPair, "PR: Liquidity is already added!");
        
        address wethAndUsdtPairContract = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).
            getPair(USDT_TOKEN_ADDRESS, WETH_TOKEN_ADDRESS);
        (uint usdtBalance, uint wethBalance1, ) = IUniswapV2Pair(wethAndUsdtPairContract).getReserves();
        if (USDT_TOKEN_ADDRESS > WETH_TOKEN_ADDRESS)
        {
            (usdtBalance, wethBalance1) = (wethBalance1, usdtBalance);
        }
        
        totalTokenSupply = (usdtBalance * totalInvestedWeth * 10**(36-USDT_DECIMALS)) / (fixedPriceInUsd * wethBalance1);
        uint amountOfTokensForUniswap = (totalTokenSupply * getUniswapSupplyPercent()) / PERCENT_DENORM;
        amountOfTokensForInvestors = amountOfTokensForUniswap;
        
        IWeth iWeth = IWeth(WETH_TOKEN_ADDRESS);
        iWeth.transfer(
                wethAndTokenPairContract, 
                iWeth.balanceOf(address(this))
            );
        
        IDefiFactoryToken(tokenAddress).mintHumanAddress(wethAndTokenPairContract, amountOfTokensForUniswap);
        
        IUniswapV2Pair iPair = IUniswapV2Pair(wethAndTokenPairContract);
        iPair.mint(address(this));
        
        if (TEAM_FINANCE_ADDRESS != BURN_ADDRESS)
        {
            IWeth(wethAndTokenPairContract).approve(TEAM_FINANCE_ADDRESS, type(uint).max);
            ITeamFinance(TEAM_FINANCE_ADDRESS).
                lockTokens(
                        wethAndTokenPairContract, 
                        _msgSender(), 
                        IWeth(wethAndTokenPairContract).balanceOf(address(this)), 
                        block.timestamp + uniswapLiquidityLockedFor
                    );
        }
        
        IDefiFactoryToken(tokenAddress).mintHumanAddress(address(this), totalTokenSupply - amountOfTokensForUniswap);
    
        changeState(States.AddedLiquidity);
    }

    function setVestingForTokenomicsTokens()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.AddedLiquidity, "PR: Tokenomics tokens have already been distributed!");
        
        for(uint i = 0; i < tokenomics.length; i++)
        {
            vesting.push(
                Vesting(
                    tokenomics[i].tokenomicsAddr,
                    (totalTokenSupply * tokenomics[i].tokenomicsPercentage ) / PERCENT_DENORM,
                    0,
                    block.timestamp + tokenomics[i].tokenomicsLockedForXSeconds,
                    block.timestamp + tokenomics[i].tokenomicsVestedForXSeconds
                )
            );
        }
        
        changeState(States.SetVestingForTokenomicsTokens);
    }

    function setVestingForInvestorsTokens(uint offset, uint limit)
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.SetVestingForTokenomicsTokens, "PR: Investors tokens have already been distributed!");
        
        Investor[] memory investorsList = listInvestors(offset, limit);
        for(uint i = 0; i < investorsList.length; i++)
        {
            vesting[cachedIndexVesting[investorsList[i].investorAddr] - 1] = Vesting(
                investorsList[i].investorAddr,
                (amountOfTokensForInvestors * investorsList[i].wethValue ) / totalInvestedWeth,
                0,
                block.timestamp + presaleLockedFor,
                block.timestamp + presaleVestedFor
            );
        }
        
        changeState(States.SetVestingForInvestorsTokens);
    }
    
    
    function setVestingForReferralsTokens(uint offset, uint limit)
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.SetVestingForInvestorsTokens, "PR: Referrals tokens have already been distributed!");
        
        Referral[] memory referralsList = listReferrals(offset, limit);
        for(uint i = 0; i < referralsList.length; i++)
        {
            vesting[cachedIndexVesting[referralsList[i].referralAddr] - 1] = Vesting(
                referralsList[i].referralAddr,
                (referralsList[i].earnings * amountOfTokensForInvestors) / totalInvestedWeth,
                0,
                block.timestamp + referralsLockedFor,
                block.timestamp + referralsVestedFor
            );
        }
        
        changeState(States.SetVestingForReferralsTokens);
    }
    
    
    function emergencyRefund(uint offset, uint limit)
        public
        onlyRole(ROLE_ADMIN)
    {
        uint wethBalance = IWeth(WETH_TOKEN_ADDRESS).balanceOf(address(this));
        if (wethBalance > 0)
        {
            IWeth(WETH_TOKEN_ADDRESS).withdraw(wethBalance);
        }
        
        Investor[] memory investorsList = listInvestors(offset, limit);
        for(uint i = 0; i < investorsList.length; i++)
        {
            uint amountToTransfer = investorsList[i].wethValue;
            investorsList[i].wethValue = 0;
            payable(investorsList[i].investorAddr).transfer(amountToTransfer);
        }
        
        changeState(States.AcceptingPayments);
    }
    
    // --------------------------------------
    
    function getInvestorsCount()
        public
        view
        returns(uint)
    {
        return investors.length;
    }
    
    function getInvestorByAddr(address addr)
        public
        view
        returns(Investor memory)
    {
        return investors[cachedIndexInvestors[addr] - 1];
    }
    
    function getInvestorByPos(uint pos)
        public
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
    
    // --------------------------------------
    
    function getReferralsCount()
        public
        view
        returns(uint)
    {
        return referrals.length;
    }
    
    function getReferralByAddr(address addr)
        public
        view
        returns(Referral memory)
    {
        return referrals[cachedIndexReferrals[addr] - 1];
    }
    
    function getReferralByPos(uint pos)
        public
        view
        returns(Referral memory)
    {
        return referrals[pos];
    }
    
    function listReferrals(uint offset, uint limit)
        public
        view
        returns(Referral[] memory)
    {
        uint start = offset;
        uint end = offset + limit;
        end = (end > referrals.length)? referrals.length: end;
        uint numItems = (end > start)? end - start: 0;
        
        Referral[] memory listOfReferrals = new Referral[](numItems);
        for(uint i = start; i < end; i++)
        {
            listOfReferrals[i - start] = referrals[i];
        }
        
        return listOfReferrals;
    }
}