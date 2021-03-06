// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.4;

import "./interfaces/ITeamFinance.sol";
import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IWeth.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";

contract LiquidityForwarderDistribution is AccessControlEnumerable {
    struct Investor {
        address addr;
        uint256 percent;
    }

    enum States {
        CreatedContract,
        CreatedPair,
        DistributedInvestorsTokens,
        PreparedLiquidity,
        AddedLiquidity
    }
    States public currentState = States.CreatedContract;

    mapping(address => uint256) public cachedIndex;
    Investor[] public investors;

    uint256 public totalSupply = 18e9 * 1e18; // 18 billions
    uint256 public percentForUniswap = 15e4; // 15%
    uint256 public constant PERCENT_DENORM = 1e6; // 100%

    address public tokenAddress;
    address public WETH_TOKEN_ADDRESS;
    address public UNISWAP_V2_FACTORY_ADDRESS;
    address public wethAndTokenPairContract;

    uint256 constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 constant ETH_ROPSTEN_CHAIN_ID = 3;
    uint256 constant ETH_KOVAN_CHAIN_ID = 42;
    uint256 constant BSC_MAINNET_CHAIN_ID = 56;
    uint256 constant BSC_TESTNET_CHAIN_ID = 97;

    address public constant BURN_ADDRESS = address(0x0);

    constructor() {
        _setupRole(ROLE_ADMIN, _msgSender());
        changeState(States.CreatedContract);

        if (block.chainid == ETH_MAINNET_CHAIN_ID) {
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            WETH_TOKEN_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

            tokenAddress = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840; // TODO: Change on production
        } else if (block.chainid == BSC_MAINNET_CHAIN_ID) {
            UNISWAP_V2_FACTORY_ADDRESS = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
            WETH_TOKEN_ADDRESS = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

            tokenAddress = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840; // TODO: Change on production
        } else if (block.chainid == ETH_KOVAN_CHAIN_ID) {
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            WETH_TOKEN_ADDRESS = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;

            tokenAddress = 0x36b0660A50f40e9e1A2764Cb00351cCB3640d932;
        }

        Investor[] memory _investors = new Investor[](10); // 10 investors. Make sure to add exactly 10 below
        _investors[0] = Investor( // !!! index starts from zero !!!
            0x0100000000000000000000000000000000000001, // Investor1
            1e4 // 1%
        );
        _investors[1] = Investor(
            0x0200000000000000000000000000000000000002, // Investor2
            2e4 // 2%
        );
        _investors[2] = Investor(
            0x0300000000000000000000000000000000000003, // Investor3
            3e4 // 3%
        );
        _investors[3] = Investor(
            0x0400000000000000000000000000000000000004, // Investor4
            4e4 // 4%
        );
        _investors[4] = Investor(
            0x0500000000000000000000000000000000000005, // Investor5
            5e4 // 5%
        );
        _investors[5] = Investor(
            0x0600000000000000000000000000000000000006, // Investor6
            6e4 // 6%
        );
        _investors[6] = Investor(
            0x0700000000000000000000000000000000000007, // Investor7
            7e4 // 7%
        );
        _investors[7] = Investor(
            0x0800000000000000000000000000000000000008, // Investor8
            8e4 // 8%
        );
        _investors[8] = Investor(
            0x0900000000000000000000000000000000000009, // Investor9
            9e4 // 9%
        );
        _investors[9] = Investor(
            0x1000000000000000000000000000000000000010, // Investor10
            40e4 // 40% = 85 - (1+2+3+4+5+6+7+8+9)
        );

        // !!! Make sure that sum of percentages equals to 85e4 = PERCENT_DENORM - percentForUniswap !!!
        addInvestorsBulk(_investors);
    }

    function updateUniswapPercentage(uint256 _value)
        public
        onlyRole(ROLE_ADMIN)
    {
        percentForUniswap = _value;
    }

    function updateDefiFactoryContract(address _value)
        public
        onlyRole(ROLE_ADMIN)
    {
        tokenAddress = _value;
    }

    function checkIfPairIsCreated() public onlyRole(ROLE_ADMIN) {
        require(
            currentState == States.CreatedContract,
            "LFD: Create pair step was completed!"
        );
        require(
            tokenAddress != BURN_ADDRESS,
            "LFD: Token address was not initialized yet!"
        );

        wethAndTokenPairContract = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS)
            .getPair(tokenAddress, WETH_TOKEN_ADDRESS);

        if (wethAndTokenPairContract == BURN_ADDRESS) {
            wethAndTokenPairContract = IUniswapV2Factory(
                UNISWAP_V2_FACTORY_ADDRESS
            ).createPair(tokenAddress, WETH_TOKEN_ADDRESS);
        }

        changeState(States.CreatedPair);
    }

    function distributeInvestorsTokens() public onlyRole(ROLE_ADMIN) {
        require(
            currentState == States.CreatedPair,
            "LFD: Tokens were already distributed!"
        );

        uint256 mintAmountOfTokensToInvestor;
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(tokenAddress);
        for (uint256 i = 0; i < investors.length; i++) {
            mintAmountOfTokensToInvestor =
                (investors[i].percent * totalSupply) /
                (PERCENT_DENORM);

            if (mintAmountOfTokensToInvestor > 0) {
                iDefiFactoryToken.mintHumanAddress(
                    investors[i].addr,
                    mintAmountOfTokensToInvestor
                );
            }
        }

        changeState(States.DistributedInvestorsTokens);
    }

    receive() external payable {
        require(
            currentState == States.DistributedInvestorsTokens,
            "LFD: Accepting payments has ended!"
        );
    }

    function prepareLiqudity() public onlyRole(ROLE_ADMIN) {
        require(
            currentState == States.DistributedInvestorsTokens,
            "LFD: Preparing add liquidity is completed!"
        );
        require(
            address(this).balance > 0,
            "LFD: Ether balance must be larger than zero!"
        );

        IWeth iWeth = IWeth(WETH_TOKEN_ADDRESS);
        iWeth.deposit{value: address(this).balance}();

        changeState(States.PreparedLiquidity);
    }

    function addLiquidityOnUniswapV2() public onlyRole(ROLE_ADMIN) {
        require(
            currentState == States.PreparedLiquidity,
            "P: Liquidity is already added!"
        );

        (uint256 deftBalance, uint256 wethBalance2, ) = IUniswapV2Pair(
            wethAndTokenPairContract
        ).getReserves();
        if (tokenAddress > WETH_TOKEN_ADDRESS) {
            (deftBalance, wethBalance2) = (wethBalance2, deftBalance);
        }

        IWeth iWeth = IWeth(WETH_TOKEN_ADDRESS);
        uint256 wethAmount = iWeth.balanceOf(address(this));
        iWeth.transfer(wethAndTokenPairContract, wethAmount);

        uint256 amountOfDeftForUniswap = (totalSupply * percentForUniswap) /
            PERCENT_DENORM;
        IDefiFactoryToken(tokenAddress).mintHumanAddress(
            wethAndTokenPairContract,
            amountOfDeftForUniswap
        );

        IUniswapV2Pair iPair = IUniswapV2Pair(wethAndTokenPairContract);
        iPair.mint(msg.sender);

        changeState(States.AddedLiquidity);
    }

    function emergencyRefundEth() public onlyRole(ROLE_ADMIN) {
        uint256 wethBalance = IWeth(WETH_TOKEN_ADDRESS).balanceOf(
            address(this)
        );
        if (wethBalance > 0) {
            IWeth(WETH_TOKEN_ADDRESS).withdraw(wethBalance);
        }

        payable(msg.sender).transfer(wethBalance);
    }

    function emergencyRefundTokens(address _token) public onlyRole(ROLE_ADMIN) {
        uint256 tokenBalance = IWeth(_token).balanceOf(address(this));
        if (tokenBalance > 0) {
            IWeth(_token).transfer(msg.sender, tokenBalance);
        }
    }

    function addInvestorsBulk(Investor[] memory _investors)
        public
        onlyRole(ROLE_ADMIN)
    {
        uint256 sumPercentages;
        for (uint256 i = 0; i < _investors.length; i++) {
            addInvestor(_investors[i].addr, _investors[i].percent);
            sumPercentages += investors[i].percent;
        }

        require(
            sumPercentages == PERCENT_DENORM - percentForUniswap,
            "LFD: Percentages were set incorrectly. SUM % != PERCENT_DENORM - percentForUniswap."
        );
    }

    function addInvestor(address addr, uint256 percent) private {
        if (cachedIndex[addr] == 0) {
            investors.push(Investor(addr, percent));
            cachedIndex[addr] = investors.length;
        } else {
            investors[cachedIndex[addr] - 1].percent = percent;
        }
    }

    function deleteAllInvestors() public onlyRole(ROLE_ADMIN) {
        for (uint256 i = 0; i < investors.length; i++) {
            cachedIndex[investors[i].addr] = 0;
        }
        delete investors;
    }

    function changeState(States _value) private {
        currentState = _value;
    }
}
