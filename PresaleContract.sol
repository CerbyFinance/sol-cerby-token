// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.7;

import "./interfaces/ITeamFinance.sol";
import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IWeth.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";



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
        uint tokensClaimed;
        uint lockedUntilTimestamp;
        uint vestedUntilTimestamp;
    }
    
    enum States { 
        AcceptingPayments, 
        ReachedGoal, 
        PreparedAddLiqudity, 
        CreatedPair, 
        AddedLiquidity, 
        SetVestingForTokenomicsTokens, 
        SetVestingForInvestorsAndReferralsTokens,
        Refunded
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
    
    uint public fixedPriceInDeft = 1e19; // 10 DEFT per Token
    
    address public tokenAddress;
    address public TEAM_FINANCE_ADDRESS;
    address public WETH_TOKEN_ADDRESS;
    address public DEFT_TOKEN_ADDRESS;
    address public USDT_TOKEN_ADDRESS;
    address public UNISWAP_V2_FACTORY_ADDRESS;
    address public UNISWAP_V2_ROUTER_ADDRESS;
    address public deftAndTokenPairContract;
    
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
        presaleLockedFor = 0;
        presaleVestedFor = 1 minutes;
        referralsLockedFor = 30 seconds;
        referralsVestedFor = 2 minutes;
        
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
            
            DEFT_TOKEN_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        } else if (block.chainid == BSC_MAINNET_CHAIN_ID)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
            UNISWAP_V2_ROUTER_ADDRESS = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
            USDT_TOKEN_ADDRESS = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
            WETH_TOKEN_ADDRESS = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
            USDT_DECIMALS = 18;
            TEAM_FINANCE_ADDRESS = 0x7536592bb74b5d62eB82e8b93b17eed4eed9A85c;
            
            DEFT_TOKEN_ADDRESS = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
        } else if (block.chainid == ETH_KOVAN_CHAIN_ID)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
            USDT_TOKEN_ADDRESS = 0xec362b0EFeC60388A12A9C26071e116bFa5e3587;
            WETH_TOKEN_ADDRESS = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
            USDT_DECIMALS = 6;
            TEAM_FINANCE_ADDRESS = BURN_ADDRESS;
            
            tokenAddress = 0x5d7333f8b9B3075293F4fCf7C5Ef9793d643DD8F; // TODO: set token address for debug
            DEFT_TOKEN_ADDRESS = 0x073ce46d328524fB3529A39d64B314aB1A594a57;
        } else if (block.chainid == ETH_ROPSTEN_CHAIN_ID)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
            USDT_TOKEN_ADDRESS = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F;
            WETH_TOKEN_ADDRESS = 0xc778417E063141139Fce010982780140Aa0cD5Ab;
            USDT_DECIMALS = 6;
            TEAM_FINANCE_ADDRESS = 0x8733CAA60eDa1597336c0337EfdE27c1335F7530;
            
            DEFT_TOKEN_ADDRESS = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F;
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
    
    function getAvailableVestingTokens(address addr)
        public
        view
        returns(uint)
    {
        Vesting memory vest = vesting[cachedIndexVesting[addr] - 1];
        if  (
                block.timestamp <= vest.lockedUntilTimestamp ||
                vest.lockedUntilTimestamp > vest.vestedUntilTimestamp
            )
        {
            return 0;
        }
        
        if  (
                block.timestamp >= vest.vestedUntilTimestamp
            )
        {
            return vest.tokensReserved - vest.tokensClaimed;
        }
    
        
        uint availableByFormula = 
            (vest.tokensReserved * (block.timestamp - vest.lockedUntilTimestamp)) / (vest.vestedUntilTimestamp - vest.lockedUntilTimestamp);
        if (availableByFormula <= vest.tokensClaimed)
        {
            return 0;
        }
        return availableByFormula - vest.tokensClaimed;
    }
    
    function claimVesting()
        public
    {
        Vesting memory vest = vesting[cachedIndexVesting[msg.sender] - 1];
        require(
            block.timestamp >= vest.lockedUntilTimestamp,
            "PR: Locked period is not over yet"
        );
        require(
            vest.tokensClaimed < vest.tokensReserved,
            "PR: You have already received 100% tokens"
        );
        
        uint availableTokens = getAvailableVestingTokens(msg.sender);
        require(
            availableTokens > 0,
            "PR: There are 0 tokens available to claim right now"
        );
        
        vesting[cachedIndexVesting[msg.sender] - 1].tokensClaimed += availableTokens;
        IDefiFactoryToken(tokenAddress).mintHumanAddress(msg.sender, availableTokens);
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
        
        // TODO: check for hard cap and mark goal as reached
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
    
    function updateFixedPriceInDeft(uint _value)
        public
        onlyRole(ROLE_ADMIN)
    {
        fixedPriceInDeft = _value;
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
        checkIfPairIsCreated();
        prepareAddLiqudity();
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
    
    function checkIfPairIsCreated()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.ReachedGoal, "PR: Pair is already created!");
        require(tokenAddress != BURN_ADDRESS, "PR: Token address was not initialized yet!");

        deftAndTokenPairContract = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).
            getPair(tokenAddress, DEFT_TOKEN_ADDRESS);
        
        if (deftAndTokenPairContract == BURN_ADDRESS)
        {
            deftAndTokenPairContract = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).
                createPair(tokenAddress, DEFT_TOKEN_ADDRESS);
        }
        
        changeState(States.CreatedPair);
    }
    
    function prepareAddLiqudity()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.CreatedPair, "PR: Preparing add liquidity is completed!");
        require(address(this).balance > 0, "PR: Ether balance must be larger than zero!");
        
        IWeth iWeth = IWeth(WETH_TOKEN_ADDRESS);
        iWeth.deposit{ value: address(this).balance }();
        
        
        address deftAndWethPairContract = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).
            getPair(WETH_TOKEN_ADDRESS, DEFT_TOKEN_ADDRESS);
        uint amountOfWethToSwapToDeft = iWeth.balanceOf(address(this));
        iWeth.transfer(deftAndWethPairContract, amountOfWethToSwapToDeft);
        
        IUniswapV2Pair iPair = IUniswapV2Pair(deftAndWethPairContract);
        (uint reserveIn, uint reserveOut,) = iPair.getReserves();
        if (DEFT_TOKEN_ADDRESS > WETH_TOKEN_ADDRESS)
        {
            (reserveIn, reserveOut) = (reserveOut, reserveIn);
        }
        
        uint amountInWithFee = amountOfWethToSwapToDeft * 997;
        uint amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
        
        (uint amount0Out, uint amount1Out) = DEFT_TOKEN_ADDRESS > WETH_TOKEN_ADDRESS? 
            (uint(0), amountOut): (amountOut, uint(0));
        
        iPair.swap(
            amount0Out, 
            amount1Out, 
            address(this), 
            new bytes(0)
        );
        
        changeState(States.PreparedAddLiqudity);
    }
    
    function addLiquidityOnUniswapV2()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.PreparedAddLiqudity, "PR: Liquidity is already added!");
        
        IWeth iDeft = IWeth(DEFT_TOKEN_ADDRESS);
        uint totalInvestedDeft = iDeft.balanceOf(address(this));
        
        uint amountOfTokensForUniswap = (totalInvestedDeft * fixedPriceInDeft) / 1e18;
        
        totalTokenSupply = (amountOfTokensForUniswap * PERCENT_DENORM) / getUniswapSupplyPercent() + 1;
        amountOfTokensForInvestors = amountOfTokensForUniswap;
        
        iDeft.transfer(
                deftAndTokenPairContract, 
                totalInvestedDeft
            );
        
        IDefiFactoryToken(tokenAddress).mintHumanAddress(deftAndTokenPairContract, amountOfTokensForUniswap);
        
        IUniswapV2Pair iPair = IUniswapV2Pair(deftAndTokenPairContract);
        iPair.mint(address(this));
        
        if (TEAM_FINANCE_ADDRESS != BURN_ADDRESS)
        {
            IWeth(deftAndTokenPairContract).approve(TEAM_FINANCE_ADDRESS, type(uint).max);
            ITeamFinance(TEAM_FINANCE_ADDRESS).
                lockTokens(
                        deftAndTokenPairContract, 
                        _msgSender(), 
                        IWeth(deftAndTokenPairContract).balanceOf(address(this)), 
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
                    block.timestamp + tokenomics[i].tokenomicsLockedForXSeconds + tokenomics[i].tokenomicsVestedForXSeconds
                )
            );
        }
    }

    function setVestingForInvestorsTokens(uint offset, uint limit)
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.AddedLiquidity, "PR: Investors tokens have already been distributed!");
        
        Investor[] memory investorsList = listInvestors(offset, limit);
        for(uint i = 0; i < investorsList.length; i++)
        {
            if (vesting[cachedIndexVesting[investorsList[i].investorAddr] - 1].tokensReserved <= 1)
            {
                vesting[cachedIndexVesting[investorsList[i].investorAddr] - 1] = Vesting(
                    investorsList[i].investorAddr,
                    (amountOfTokensForInvestors * investorsList[i].wethValue ) / totalInvestedWeth,
                    0,
                    block.timestamp + presaleLockedFor,
                    block.timestamp + presaleLockedFor + presaleVestedFor
                );
            }
        }
    }
    
    function setVestingForReferralsTokens(uint offset, uint limit)
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.AddedLiquidity, "PR: Referrals tokens have already been distributed!");
        
        Referral[] memory referralsList = listReferrals(offset, limit);
        for(uint i = 0; i < referralsList.length; i++)
        {
            if (vesting[cachedIndexVesting[referralsList[i].referralAddr] - 1].tokensReserved <= 1)
            {
                vesting[cachedIndexVesting[referralsList[i].referralAddr] - 1] = Vesting(
                    referralsList[i].referralAddr,
                    (referralsList[i].earnings * amountOfTokensForInvestors) / totalInvestedWeth,
                    0,
                    block.timestamp + referralsLockedFor,
                    block.timestamp + referralsLockedFor + referralsVestedFor
                );
            }
        }
    }
    
    function checkIfAllVestingWasSet()
        public
        view
        returns (bool)
    {
        for(uint i = 0; i<referrals.length; i++)
        {
            if (vesting[cachedIndexVesting[referrals[i].referralAddr] - 1].tokensReserved <= 1)
            {
                return false;
            }
        }
        
        for(uint i = 0; i<investors.length; i++)
        {
            if (vesting[cachedIndexVesting[investors[i].investorAddr] - 1].tokensReserved <= 1)
            {
                return false;
            }
        }
        
        return true;
    }
    
    function changeStateIfAllVestingWasSet()
        public
        onlyRole(ROLE_ADMIN)
    {
        for(uint i = 0; i<referrals.length; i++)
        {
            require(
                vesting[cachedIndexVesting[referrals[i].referralAddr] - 1].tokensReserved > 1, 
                "PR: Not all investor's vesting was set!"
            );
        }
        
        for(uint i = 0; i<investors.length; i++)
        {
            require(
                vesting[cachedIndexVesting[investors[i].investorAddr] - 1].tokensReserved > 1, 
                "PR: Not all investor's vesting was set!"
            );
        }
        
        changeState(States.SetVestingForInvestorsAndReferralsTokens);
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
        
        changeState(States.Refunded);
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