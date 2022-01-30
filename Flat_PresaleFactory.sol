// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.7;

interface ITeamFinance {
    function lockTokens(
        address _tokenAddress,
        address _withdrawalAddress,
        uint256 _amount,
        uint256 _unlockTime
    ) external returns (uint256 _id);
}

struct AccessSettings {
    bool isMinter;
    bool isBurner;
    bool isTransferer;
    bool isModerator;
    bool isTaxer;
    address addr;
}

interface IDefiFactoryToken {
    function approve(address _spender, uint256 _value)
        external
        returns (bool success);

    function balanceOf(address account) external view returns (uint256);

    function chargeCustomTax(address from, uint256 amount) external;

    function mintHumanAddress(address to, uint256 desiredAmountToMint) external;

    function burnHumanAddress(address from, uint256 desiredAmountToBurn)
        external;

    function mintByBridge(address to, uint256 realAmountToMint) external;

    function burnByBridge(address from, uint256 realAmountBurn) external;

    function getUtilsContractAtPos(uint256 pos) external view returns (address);

    function transferFromTeamVestingContract(address recipient, uint256 amount)
        external;

    function correctTransferEvents(address[] calldata addrs) external;

    function publicForcedUpdateCacheMultiplier() external;

    function updateUtilsContracts(AccessSettings[] calldata accessSettings)
        external;

    function transferCustom(
        address sender,
        address recipient,
        uint256 amount
    ) external;
}

interface IUniswapV2Factory {
    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address);

    function createPair(address tokenA, address tokenB)
        external
        returns (address);
}

interface IUniswapV2Pair {
    function sync() external;

    function getReserves()
        external
        view
        returns (
            uint256,
            uint256,
            uint32
        );

    function token0() external view returns (address);

    function token1() external view returns (address);

    function mint(address to) external returns (uint256);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;
}

interface IWeth {
    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint256);

    function transfer(address _to, uint256 _value)
        external
        returns (bool success);

    function mint(address to, uint256 desiredAmountToMint) external;

    function burn(address from, uint256 desiredAmountBurn) external;

    function deposit() external payable;

    function withdraw(uint256 wad) external;

    function approve(address _spender, uint256 _value)
        external
        returns (bool success);
}

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

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
    Vesting[] vesting;

    mapping(address => uint256) cachedIndexReferrals;
    Referral[] referrals;

    mapping(address => uint256) cachedIndexTokenomics;
    Tokenomics[] tokenomics;

    uint256 refPercent = 5e4; // 5%
    uint256 constant PERCENT_DENORM = 1e6;

    uint256 totalInvestedWeth;

    uint256 public amountOfTokensForInvestors;
    uint256 public totalTokenSupply;

    uint256 fixedPriceInDeft = 1e19; // 10 DEFT per Token

    /* Kovan */
    address constant UNISWAP_V2_FACTORY_ADDRESS =
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address constant USDT_TOKEN_ADDRESS =
        0xec362b0EFeC60388A12A9C26071e116bFa5e3587;
    address constant WETH_TOKEN_ADDRESS =
        0xd0A1E359811322d97991E03f863a0C30C2cF029C;
    uint256 constant USDT_DECIMALS = 6;
    address constant TEAM_FINANCE_ADDRESS = BURN_ADDRESS;
    address constant DEFT_TOKEN_ADDRESS =
        0x073ce46d328524fB3529A39d64B314aB1A594a57;

    address deftAndTokenPairContract;

    uint256 constant TOKEN_DECIMALS = 18;
    uint256 constant WETH_DECIMALS = 18;

    address constant DEFAULT_REFERRAL_ADDRESS =
        0xC427a912E0B19f082840A0045E430dE5b8cB1f65;

    address constant BURN_ADDRESS = address(0x0);

    Settings public settings;

    event StateChanged(States newState);

    /* Referral wallet for tests: 0xDc15Ca882F975c33D8f20AB3669D27195B8D87a6 */

    constructor(Tokenomics[] memory _tokenomics, Settings memory _settings) {
        for (uint256 i; i < _tokenomics.length; i++) {
            addTokenomics(_tokenomics[i]);
        }

        settings = _settings;

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
            _vesting = Vesting(wallet, 0, 0, 0, 0);
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
            _walletInfo = WalletInfo(wallet, 0, 0, 0, 0);
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
            settings.maxWethCap,
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
            fixedPriceInDeft,
            block.timestamp // TODO: change
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
            cachedIndexReferrals[referralAddr] == 0,
            "PR: Please use different referral link"
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
            vesting.push(Vesting(vestingAddr, 1, 1, 1, 1));
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
        return (tokenomics);
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

        address deftAndWethPairContract = IUniswapV2Factory(
            UNISWAP_V2_FACTORY_ADDRESS
        ).getPair(WETH_TOKEN_ADDRESS, DEFT_TOKEN_ADDRESS);
        uint256 amountOfWethToSwapToDeft = iWeth.balanceOf(address(this));
        iWeth.transfer(deftAndWethPairContract, amountOfWethToSwapToDeft);

        IUniswapV2Pair iPair = IUniswapV2Pair(deftAndWethPairContract);
        (uint256 reserveIn, uint256 reserveOut, ) = iPair.getReserves();
        if (DEFT_TOKEN_ADDRESS > WETH_TOKEN_ADDRESS) {
            (reserveIn, reserveOut) = (reserveOut, reserveIn);
        }

        uint256 amountInWithFee = amountOfWethToSwapToDeft * 997;
        uint256 amountOut = (amountInWithFee * reserveOut) /
            (reserveIn * 1000 + amountInWithFee);

        (uint256 amount0Out, uint256 amount1Out) = DEFT_TOKEN_ADDRESS >
            WETH_TOKEN_ADDRESS
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));

        iPair.swap(amount0Out, amount1Out, address(this), new bytes(0));

        changeState(States.PreparedAddLiqudity);
    }

    function addLiquidityOnUniswapV2() public onlyOwner {
        require(
            state == States.PreparedAddLiqudity,
            "PR: Liquidity is already added!"
        );

        IWeth iDeft = IWeth(DEFT_TOKEN_ADDRESS);
        uint256 totalInvestedDeft = iDeft.balanceOf(address(this));

        uint256 amountOfTokensForUniswap = (totalInvestedDeft *
            fixedPriceInDeft) / 1e18;

        totalTokenSupply =
            (amountOfTokensForUniswap * PERCENT_DENORM) /
            getUniswapSupplyPercent() +
            1;
        amountOfTokensForInvestors = amountOfTokensForUniswap;

        iDeft.transfer(deftAndTokenPairContract, totalInvestedDeft);

        IDefiFactoryToken(settings.tokenAddress).mintHumanAddress(
            deftAndTokenPairContract,
            amountOfTokensForUniswap
        );

        IUniswapV2Pair iPair = IUniswapV2Pair(deftAndTokenPairContract);
        iPair.mint(address(this));

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
            vesting.push(
                Vesting(
                    tokenomics[i].tokenomicsAddr,
                    (totalTokenSupply * tokenomics[i].tokenomicsPercentage) /
                        PERCENT_DENORM,
                    0,
                    block.timestamp + tokenomics[i].tokenomicsLockedForXSeconds,
                    block.timestamp +
                        tokenomics[i].tokenomicsLockedForXSeconds +
                        tokenomics[i].tokenomicsVestedForXSeconds
                )
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
                    .tokensReserved <= 1
            ) {
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
                    .tokensReserved <= 1
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

contract PresaleFactory {
    PresaleContract[] public presaleContracts;

    /*
tuple(address,string,uint256,uint256,uint256)[]: 0x1111BEe701Ef814A2B6A3EDD4B1652cB9cc5aA6f,Development,150000,60,600,0x2222bEE701Ef814a2B6a3edD4B1652cB9Cc5Aa6F,Marketing,100000,120,1200,0x3333BeE701EF814A2b6a3edD4B1652cb9Cc5AA6F,Advisors,50000,180,1800
1:
tuple(address,string,string,string,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256): 0x5d7333f8b9B3075293F4fCf7C5Ef9793d643DD8F,Lambo Token Presale,https://lambo.defifactory.finance,https://t.me/LamboTokenOwners,3153600000,0,60,30,120,1000000000000000000000,1000000000000000,1000000000000000000*/

    function createPresale(
        Tokenomics[] memory _tokenomics,
        Settings memory _settings
    ) external returns (address) {
        presaleContracts.push(new PresaleContract(_tokenomics, _settings));

        return (address(presaleContracts[presaleContracts.length - 1]));
    }

    function listPresales(
        address walletAddress,
        uint256 page,
        uint256 limit
    ) external view returns (OutputItem[] memory output) {
        uint256 start = (page - 1) * limit;
        uint256 end = page * limit;
        end = (end > presaleContracts.length) ? presaleContracts.length : end;
        uint256 numItems = (end > start) ? end - start : 0;

        output = new OutputItem[](numItems);
        for (uint256 i = start; i < end; i++) {
            output[i - start] = presaleContracts[i].getInformation(
                walletAddress
            );
        }

        return output;
    }
}
