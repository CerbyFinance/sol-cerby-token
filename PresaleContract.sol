// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.7;

import "./interfaces/ITeamFinance.sol";
import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IWeth.sol";
import "./openzeppelin/access/Ownable.sol";

struct Tokenomics {
    address tokenomicsAddr;
    string tokenomicsName;
    uint256 tokenomicsPercentage;
    uint256 tokenomicsLockedForXSeconds;
    uint256 tokenomicsVestedForXSeconds;
}

struct Settings {
    address tokenAddress;
    string presaleName;
    string website;
    string telegram;
    uint256 uniswapLiquidityLockedFor;
    uint256 presaleLockedFor;
    uint256 presaleVestedFor;
    uint256 referralsLockedFor;
    uint256 referralsVestedFor;
    uint256 maxWethCap;
    uint256 perWalletMinWeth;
    uint256 perWalletMaxWeth;
    uint256 fixedPriceInDeft;
}

struct PresaleItem {
    address presaleContractAddress;
    string presaleName;
    uint256 totalInvestedWeth;
    uint256 maxWethCap;
    bool isActive;
    bool isEnabled;
    string website;
    string telegram;
}

struct WalletInfo {
    address walletAddress;
    uint256 walletInvestedWeth;
    uint256 walletReferralEarnings;
    uint256 minimumWethPerWallet;
    uint256 maximumWethPerWallet;
}

struct Vesting {
    address vestingAddr;
    uint256 tokensReserved;
    uint256 tokensClaimed;
    uint256 lockedUntilTimestamp;
    uint256 vestedUntilTimestamp;
}

struct OutputItem {
    PresaleItem presaleItem;
    WalletInfo walletInfo;
    Vesting vestingInfo;
    Tokenomics[] tokenomics;
    uint256 listingPrice;
    uint256 createdAt;
}

contract PresaleContract is Ownable {
    struct Investor {
        address investorAddr;
        address referralAddr;
        uint256 wethValue;
    }

    struct Referral {
        address referralAddr;
        uint256 earnings;
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

    mapping(address => uint256) cachedIndexInvestors;
    Investor[] investors;

    mapping(address => uint256) cachedIndexVesting;
    Vesting[] public vesting;

    mapping(address => uint256) cachedIndexReferrals;
    Referral[] referrals;

    mapping(address => uint256) cachedIndexTokenomics;
    Tokenomics[] tokenomics;

    uint256 refPercent = 5e4; // 5%
    uint256 constant PERCENT_DENORM = 1e6;

    uint256 totalInvestedWeth;
    uint256 createdAt;

    uint256 public amountOfTokensForInvestors;
    uint256 public totalTokenSupply;

    /* Kovan */
    address constant UNISWAP_V2_FACTORY_ADDRESS =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant UNISWAP_V2_ROUTER_ADDRESS =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant USDT_TOKEN_ADDRESS =
        0xec362b0EFeC60388A12A9C26071e116bFa5e3587;
    address constant WETH_TOKEN_ADDRESS =
        0xd0A1E359811322d97991E03f863a0C30C2cF029C;
    uint256 constant USDT_DECIMALS = 6;
    address constant TEAM_FINANCE_ADDRESS = BURN_ADDRESS;
    address constant DEFT_TOKEN_ADDRESS =
        0xDBd240d23A5c3041b0f26BDd8888DEDE6f58a12A;

    /* Ropsten */
    /*address constant UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant USDT_TOKEN_ADDRESS = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F;
    address constant WETH_TOKEN_ADDRESS = 0xc778417E063141139Fce010982780140Aa0cD5Ab;
    uint constant USDT_DECIMALS = 6;
    address constant TEAM_FINANCE_ADDRESS = 0x8733CAA60eDa1597336c0337EfdE27c1335F7530;
    address constant DEFT_TOKEN_ADDRESS = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F;*/

    address deftAndTokenPairContract;

    uint256 constant TOKEN_DECIMALS = 18;
    uint256 constant WETH_DECIMALS = 18;

    address constant DEFAULT_REFERRAL_ADDRESS =
        0xC427a912E0B19f082840A0045E430dE5b8cB1f65;

    address constant BURN_ADDRESS = address(0x0);

    Settings public settings;

    event StateChanged(States newState);

    /* Referral wallet for tests: 0xDc15Ca882F975c33D8f20AB3669D27195B8D87a6 */

    constructor(
        address owner,
        Tokenomics[] memory _tokenomics,
        Settings memory _settings
    ) {
        _owner = owner;
        emit OwnershipTransferred(address(0), owner);

        for (uint256 i; i < _tokenomics.length; i++) {
            addTokenomics(_tokenomics[i]);
        }

        settings = _settings;

        createdAt = block.timestamp;

        changeState(States.AcceptingPayments);
    }

    receive() external payable {}

    function getInformation(address wallet)
        public
        view
        returns (OutputItem memory output)
    {
        Vesting memory _vesting;
        if (cachedIndexVesting[wallet] > 0) {
            _vesting = vesting[cachedIndexVesting[wallet] - 1];
        } else {
            _vesting = Vesting(wallet, 0, 0, block.timestamp, block.timestamp);
        }

        WalletInfo memory _walletInfo;
        if (cachedIndexInvestors[wallet] > 0) {
            Investor memory _investor = investors[
                cachedIndexInvestors[wallet] - 1
            ];

            _walletInfo = WalletInfo(
                wallet,
                _investor.wethValue,
                0,
                settings.perWalletMinWeth,
                settings.perWalletMaxWeth
            );
        } else {
            _walletInfo = WalletInfo(
                wallet,
                0,
                0,
                settings.perWalletMinWeth,
                settings.perWalletMaxWeth
            );
        }

        if (cachedIndexReferrals[wallet] > 0) {
            _walletInfo.walletReferralEarnings = referrals[
                cachedIndexReferrals[wallet] - 1
            ].earnings;
        }

        PresaleItem memory _presaleItem = PresaleItem(
            address(this),
            settings.presaleName,
            totalInvestedWeth,
            settings.maxWethCap, // TODO: calculate max weth cap based on 5% of deft liquidity
            /*isActive:*/
            totalInvestedWeth < settings.maxWethCap,
            /*isEnabled:*/
            true,
            settings.website,
            settings.telegram
        );

        output = OutputItem(
            _presaleItem,
            _walletInfo,
            _vesting,
            getTokenomics(),
            settings.fixedPriceInDeft,
            createdAt
        );

        return output;
    }

    function updateSettings(Settings calldata _settings) external onlyOwner {
        settings = _settings;
    }

    function getUniswapSupplyPercent() internal view returns (uint256) {
        uint256 totalTeamPercent;
        for (uint256 i; i < tokenomics.length; i++) {
            totalTeamPercent += tokenomics[i].tokenomicsPercentage;
        }
        return
            (PERCENT_DENORM * (PERCENT_DENORM - totalTeamPercent)) /
            (2 * PERCENT_DENORM + refPercent);
    }

    function getAvailableVestingTokens(address addr)
        public
        view
        returns (uint256)
    {
        Vesting memory vest = vesting[cachedIndexVesting[addr] - 1];
        if (
            block.timestamp <= vest.lockedUntilTimestamp ||
            vest.lockedUntilTimestamp > vest.vestedUntilTimestamp
        ) {
            return 0;
        }

        if (block.timestamp >= vest.vestedUntilTimestamp) {
            return vest.tokensReserved - vest.tokensClaimed;
        }

        uint256 availableByFormula = (vest.tokensReserved *
            (block.timestamp - vest.lockedUntilTimestamp)) /
            (vest.vestedUntilTimestamp - vest.lockedUntilTimestamp);
        if (availableByFormula <= vest.tokensClaimed) {
            return 0;
        }
        return availableByFormula - vest.tokensClaimed;
    }

    function claimVesting() external {
        Vesting memory vest = vesting[cachedIndexVesting[msg.sender] - 1];
        require(
            block.timestamp >= vest.lockedUntilTimestamp,
            "PR: Locked period is not over yet"
        );
        require(
            vest.tokensClaimed < vest.tokensReserved,
            "PR: You have already received 100% tokens"
        );

        uint256 availableTokens = getAvailableVestingTokens(msg.sender);
        require(
            availableTokens > 0,
            "PR: There are 0 tokens available to claim right now"
        );

        vesting[cachedIndexVesting[msg.sender] - 1]
            .tokensClaimed += availableTokens;
        IDefiFactoryToken(settings.tokenAddress).mintHumanAddress(
            msg.sender,
            availableTokens
        );

        //IDefiFactoryToken(settings.tokenAddress).mintHumanAddress(msg.sender, 1e18);
    }

    function invest(address referralAddr) external payable {
        require(
            state == States.AcceptingPayments,
            "PR: Accepting payments has been stopped!"
        );
        require(
            totalInvestedWeth <= settings.maxWethCap,
            "PR: Max cap reached!"
        );
        require(
            msg.value >= settings.perWalletMinWeth,
            "PR: Amount is below minimum permitted"
        );
        require(
            msg.value <= settings.perWalletMaxWeth,
            "PR: Amount is above maximum permitted"
        );
        require(
            cachedIndexTokenomics[msg.sender] == 0,
            "PR: Team is not allowed to invest"
        );
        require(
            cachedIndexReferrals[msg.sender] == 0,
            "PR: Investing for active referral addresses is forbidden"
        );
        require(
            msg.sender != referralAddr,
            "PR: Self-ref isn't allowed. Please use different referral link"
        );

        if (referralAddr == BURN_ADDRESS) {
            referralAddr = DEFAULT_REFERRAL_ADDRESS;
        }

        addInvestor(msg.sender, referralAddr, msg.value);

        addReferral(referralAddr, (msg.value * refPercent) / PERCENT_DENORM);
    }

    function addInvestor(
        address investorAddr,
        address referralAddr,
        uint256 wethValue
    ) internal {
        if (cachedIndexInvestors[investorAddr] == 0) {
            investors.push(Investor(investorAddr, referralAddr, wethValue));
            cachedIndexInvestors[investorAddr] = investors.length;
        } else {
            uint256 updatedWethValue = investors[
                cachedIndexInvestors[investorAddr] - 1
            ].wethValue + wethValue;
            require(
                updatedWethValue <= settings.perWalletMaxWeth,
                "PR: Max cap per wallet exceeded"
            );

            investors[cachedIndexInvestors[investorAddr] - 1]
                .wethValue = updatedWethValue;
        }
        totalInvestedWeth += wethValue;

        createVestingIfDoesNotExist(investorAddr);
    }

    function addReferral(address referralAddr, uint256 earnings) internal {
        if (cachedIndexReferrals[referralAddr] == 0) {
            referrals.push(Referral(referralAddr, earnings));
            cachedIndexReferrals[referralAddr] = referrals.length;
        } else {
            referrals[cachedIndexReferrals[referralAddr] - 1]
                .earnings += earnings;
        }

        createVestingIfDoesNotExist(referralAddr);
    }

    function addTokenomics(Tokenomics memory _input) internal {
        if (cachedIndexTokenomics[_input.tokenomicsAddr] == 0) {
            tokenomics.push(_input);
            cachedIndexTokenomics[_input.tokenomicsAddr] = tokenomics.length;
        } else {
            tokenomics[
                cachedIndexTokenomics[_input.tokenomicsAddr] - 1
            ] = _input;
        }

        createVestingIfDoesNotExist(_input.tokenomicsAddr);
    }

    function checkIfTokenomicsIsValid() public view returns (bool) {
        uint256 totalPercentage;
        for (uint256 i; i < tokenomics.length; i++) {
            totalPercentage += tokenomics[i].tokenomicsPercentage;
        }

        return totalPercentage <= ((PERCENT_DENORM * 30) / 100);
    }

    function createVestingIfDoesNotExist(address vestingAddr) internal {
        if (cachedIndexVesting[vestingAddr] == 0) {
            vesting.push(
                Vesting(vestingAddr, 0, 0, block.timestamp, block.timestamp)
            );
            cachedIndexVesting[vestingAddr] = vesting.length;
        }
    }

    function getTokenomics() public view returns (Tokenomics[] memory) {
        uint256 uniswapSupplyPercent = getUniswapSupplyPercent();
        Tokenomics[] memory output = new Tokenomics[](3 + tokenomics.length);
        output[0] = Tokenomics(
            address(0x1),
            "Liquidity",
            uniswapSupplyPercent,
            settings.uniswapLiquidityLockedFor,
            0
        );
        output[1] = Tokenomics(
            address(0x2),
            "Presale",
            uniswapSupplyPercent,
            settings.presaleLockedFor,
            settings.presaleVestedFor
        );
        output[2] = Tokenomics(
            address(0x3),
            "Referrals",
            (uniswapSupplyPercent * refPercent) / PERCENT_DENORM,
            settings.referralsLockedFor,
            settings.referralsVestedFor
        );

        for (uint256 i; i < tokenomics.length; i++) {
            output[i + 3] = tokenomics[i];
        }
        return (output);
    }

    function changeState(States _value) private {
        state = _value;
        emit StateChanged(_value);
    }

    function skipSteps1() public {
        markGoalAsReached();
        checkIfPairIsCreated();
        prepareAddLiqudity();
    }

    function skipSteps2(uint256 limit) public {
        addLiquidityOnUniswapV2();

        setVestingForTokenomicsTokens();

        limit = limit == 0 ? investors.length : limit;
        setVestingForInvestorsTokens(0, limit);

        limit = limit == 0 ? investors.length : limit;
        setVestingForReferralsTokens(0, limit);
    }

    function markGoalAsReached() public onlyOwner {
        require(
            state == States.AcceptingPayments,
            "PR: Goal is already reached!"
        );

        settings.maxWethCap = totalInvestedWeth;

        changeState(States.ReachedGoal);
    }

    function checkIfPairIsCreated() public onlyOwner {
        require(state == States.ReachedGoal, "PR: Pair is already created!");
        require(
            settings.tokenAddress != BURN_ADDRESS,
            "PR: Token address was not initialized yet!"
        );

        deftAndTokenPairContract = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS)
            .getPair(settings.tokenAddress, DEFT_TOKEN_ADDRESS);

        if (deftAndTokenPairContract == BURN_ADDRESS) {
            deftAndTokenPairContract = IUniswapV2Factory(
                UNISWAP_V2_FACTORY_ADDRESS
            ).createPair(settings.tokenAddress, DEFT_TOKEN_ADDRESS);
        }

        changeState(States.CreatedPair);
    }

    function prepareAddLiqudity() public onlyOwner {
        require(
            state == States.CreatedPair,
            "PR: Preparing add liquidity is completed!"
        );
        require(
            address(this).balance > 0,
            "PR: Ether balance must be larger than zero!"
        );

        IWeth iWeth = IWeth(WETH_TOKEN_ADDRESS);
        iWeth.deposit{value: address(this).balance}();

        uint256 amountOfWethToSwapToDeft = iWeth.balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = WETH_TOKEN_ADDRESS;
        path[1] = DEFT_TOKEN_ADDRESS;

        iWeth.approve(UNISWAP_V2_ROUTER_ADDRESS, type(uint256).max);
        IWeth(DEFT_TOKEN_ADDRESS).approve(
            UNISWAP_V2_ROUTER_ADDRESS,
            type(uint256).max
        );
        IWeth(settings.tokenAddress).approve(
            UNISWAP_V2_ROUTER_ADDRESS,
            type(uint256).max
        );

        IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                amountOfWethToSwapToDeft,
                0,
                path,
                address(this),
                block.timestamp + 8640000
            );

        /*address deftAndWethPairContract = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).
            getPair(WETH_TOKEN_ADDRESS, DEFT_TOKEN_ADDRESS);
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
        );*/

        changeState(States.PreparedAddLiqudity);
    }

    function addLiquidityOnUniswapV2() public onlyOwner {
        require(
            state == States.PreparedAddLiqudity,
            "PR: Liquidity is already added!"
        );

        IWeth iDeft = IWeth(DEFT_TOKEN_ADDRESS);
        uint256 totalInvestedDeft = iDeft.balanceOf(address(this));

        uint256 amountOfTokensForUniswap = (totalInvestedDeft * 1e18) /
            settings.fixedPriceInDeft;

        totalTokenSupply =
            (amountOfTokensForUniswap * PERCENT_DENORM) /
            getUniswapSupplyPercent() +
            1;
        amountOfTokensForInvestors = amountOfTokensForUniswap;

        IDefiFactoryToken(settings.tokenAddress).mintHumanAddress(
            address(this),
            amountOfTokensForUniswap
        );

        IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS).addLiquidity(
            DEFT_TOKEN_ADDRESS,
            settings.tokenAddress,
            totalInvestedDeft,
            amountOfTokensForUniswap,
            0,
            0,
            address(this),
            block.timestamp + 8640000
        );

        /*iDeft.transfer(
                deftAndTokenPairContract, 
                totalInvestedDeft
            );
        
        
        IDefiFactoryToken(settings.tokenAddress).mintHumanAddress(deftAndTokenPairContract, amountOfTokensForUniswap);
        
        IUniswapV2Pair iPair = IUniswapV2Pair(deftAndTokenPairContract);
        iPair.mint(address(this));*/

        if (TEAM_FINANCE_ADDRESS != BURN_ADDRESS) {
            IWeth(deftAndTokenPairContract).approve(
                TEAM_FINANCE_ADDRESS,
                type(uint256).max
            );
            ITeamFinance(TEAM_FINANCE_ADDRESS).lockTokens(
                deftAndTokenPairContract,
                _msgSender(),
                IWeth(deftAndTokenPairContract).balanceOf(address(this)),
                block.timestamp + settings.uniswapLiquidityLockedFor
            );
        }

        IDefiFactoryToken(settings.tokenAddress).mintHumanAddress(
            address(this),
            totalTokenSupply - amountOfTokensForUniswap
        );

        changeState(States.AddedLiquidity);
    }

    function setVestingForTokenomicsTokens() public {
        require(
            state == States.AddedLiquidity,
            "PR: Tokenomics tokens have already been distributed!"
        );

        for (uint256 i = 0; i < tokenomics.length; i++) {
            vesting[
                cachedIndexVesting[tokenomics[i].tokenomicsAddr] - 1
            ] = Vesting(
                tokenomics[i].tokenomicsAddr,
                (totalTokenSupply * tokenomics[i].tokenomicsPercentage) /
                    PERCENT_DENORM,
                0,
                block.timestamp + tokenomics[i].tokenomicsLockedForXSeconds,
                block.timestamp +
                    tokenomics[i].tokenomicsLockedForXSeconds +
                    tokenomics[i].tokenomicsVestedForXSeconds
            );
        }
    }

    function setVestingForInvestorsTokens(uint256 offset, uint256 limit)
        public
    {
        require(
            state == States.AddedLiquidity,
            "PR: Investors tokens have already been distributed!"
        );

        Investor[] memory investorsList = listInvestors(offset, limit);
        for (uint256 i = 0; i < investorsList.length; i++) {
            if (
                vesting[cachedIndexVesting[investorsList[i].investorAddr] - 1]
                    .tokensReserved == 0
            ) // ???????????? ?????? ???????? <= 1 ?
            {
                vesting[
                    cachedIndexVesting[investorsList[i].investorAddr] - 1
                ] = Vesting(
                    investorsList[i].investorAddr,
                    (amountOfTokensForInvestors * investorsList[i].wethValue) /
                        totalInvestedWeth,
                    0,
                    block.timestamp + settings.presaleLockedFor,
                    block.timestamp +
                        settings.presaleLockedFor +
                        settings.presaleVestedFor
                );
            }
        }
    }

    function setVestingForReferralsTokens(uint256 offset, uint256 limit)
        public
    {
        require(
            state == States.AddedLiquidity,
            "PR: Referrals tokens have already been distributed!"
        );

        Referral[] memory referralsList = listReferrals(offset, limit);
        for (uint256 i = 0; i < referralsList.length; i++) {
            if (
                vesting[cachedIndexVesting[referralsList[i].referralAddr] - 1]
                    .tokensReserved == 0
            ) {
                vesting[
                    cachedIndexVesting[referralsList[i].referralAddr] - 1
                ] = Vesting(
                    referralsList[i].referralAddr,
                    (referralsList[i].earnings * amountOfTokensForInvestors) /
                        totalInvestedWeth,
                    0,
                    block.timestamp + settings.referralsLockedFor,
                    block.timestamp +
                        settings.referralsLockedFor +
                        settings.referralsVestedFor
                );
            }
        }
    }

    function checkIfAllVestingWasSet() public view returns (bool) {
        for (uint256 i = 0; i < referrals.length; i++) {
            if (
                vesting[cachedIndexVesting[referrals[i].referralAddr] - 1]
                    .tokensReserved <= 1
            ) {
                return false;
            }
        }

        for (uint256 i = 0; i < investors.length; i++) {
            if (
                vesting[cachedIndexVesting[investors[i].investorAddr] - 1]
                    .tokensReserved <= 1
            ) {
                return false;
            }
        }

        return true;
    }

    function emergencyRefund(uint256 offset, uint256 limit) public onlyOwner {
        changeState(States.Refunded);

        uint256 wethBalance = IWeth(WETH_TOKEN_ADDRESS).balanceOf(
            address(this)
        );
        if (wethBalance > 0) {
            IWeth(WETH_TOKEN_ADDRESS).withdraw(wethBalance);
        }

        Investor[] memory investorsList = listInvestors(offset, limit);
        for (uint256 i = 0; i < investorsList.length; i++) {
            uint256 amountToTransfer = investorsList[i].wethValue;
            investorsList[i].wethValue = 0;
            payable(investorsList[i].investorAddr).transfer(amountToTransfer);
        }
    }

    // --------------------------------------

    /*function getInvestorsCount()
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
    }*/

    function listInvestors(uint256 offset, uint256 limit)
        public
        view
        returns (Investor[] memory)
    {
        uint256 start = offset;
        uint256 end = offset + limit;
        end = (end > investors.length) ? investors.length : end;
        uint256 numItems = (end > start) ? end - start : 0;

        Investor[] memory listOfInvestors = new Investor[](numItems);
        for (uint256 i = start; i < end; i++) {
            listOfInvestors[i - start] = investors[i];
        }

        return listOfInvestors;
    }

    // --------------------------------------

    /*function getReferralsCount()
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
    }*/

    function listReferrals(uint256 offset, uint256 limit)
        public
        view
        returns (Referral[] memory)
    {
        uint256 start = offset;
        uint256 end = offset + limit;
        end = (end > referrals.length) ? referrals.length : end;
        uint256 numItems = (end > start) ? end - start : 0;

        Referral[] memory listOfReferrals = new Referral[](numItems);
        for (uint256 i = start; i < end; i++) {
            listOfReferrals[i - start] = referrals[i];
        }

        return listOfReferrals;
    }
}
