// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.4;

import "./interfaces/ITeamFinance.sol";
import "./interfaces/IDefiFactoryToken.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IWeth.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";


contract PresaleBSC is AccessControlEnumerable {
    
    struct Investor {
        address addr;
        uint wethValue;
        uint sentValue;
    }
    
    enum States { AcceptingPayments, ReachedGoal, PreparedAddLiqudity, CreatedPair, AddedLiquidity, DistributedTokens }
    States public state;
    
    mapping(address => uint) public cachedIndex;
    Investor[] public investors;
    
    uint public totalInvestedWeth;
    uint public maxWethCap = 1000e18;
    uint public perWalletMinWethCap = 0;
    uint public perWalletMaxWethCap = 50e18;
    uint public amountOfDeftForInvestors;
    uint public amountOfDeftForUniswap;
    uint public amountOfDeftBurned;
    uint public amountOfDeftMinted;
    
    
    address public defiFactoryTokenAddress;
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
    
    uint constant DEFT_DECIMALS = 18;
    uint constant WETH_DECIMALS = 18;
    uint USDT_DECIMALS;
    
    uint constant bonusPercent = 5e4;
    uint constant PERCENT_DENORM = 1e6;
    
    address public constant BURN_ADDRESS = address(0x0);
    
    event InvestedAmount(address investorAddr, uint investorAmountWeth);
    event StateChanged(States newState);
    
    constructor() payable {
        _setupRole(ROLE_ADMIN, _msgSender());
        
        if (block.chainid == ETH_MAINNET_CHAIN_ID)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
            USDT_TOKEN_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
            WETH_TOKEN_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
            USDT_DECIMALS = 6;
            TEAM_FINANCE_ADDRESS = 0xC77aab3c6D7dAb46248F3CC3033C856171878BD5;
            
            defiFactoryTokenAddress = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840;
        } else if (block.chainid == BSC_MAINNET_CHAIN_ID)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
            UNISWAP_V2_ROUTER_ADDRESS = 0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F;
            USDT_TOKEN_ADDRESS = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
            WETH_TOKEN_ADDRESS = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
            USDT_DECIMALS = 18;
            TEAM_FINANCE_ADDRESS = 0x7536592bb74b5d62eB82e8b93b17eed4eed9A85c;
            
            defiFactoryTokenAddress = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840;
        } else if (block.chainid == ETH_KOVAN_CHAIN_ID)
        {
            UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
            UNISWAP_V2_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
            USDT_TOKEN_ADDRESS = 0x2F375e94FC336Cdec2Dc0cCB5277FE59CBf1cAe5;
            WETH_TOKEN_ADDRESS = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
            USDT_DECIMALS = 6;
            TEAM_FINANCE_ADDRESS = BURN_ADDRESS;
            
            defiFactoryTokenAddress = 0xAa54f213dBe6ba9a1f5ceE5bCcb40Ea0e8Dd2984;
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
        
        /*addInvestor(msg.sender, msg.value);
        skipSteps1();*/
    }

    receive() external payable {
        require(state == States.AcceptingPayments, "PR: Accepting payments has been stopped!");
        require(totalInvestedWeth <= maxWethCap, "PR: Max cap reached!");
        require(msg.value >= perWalletMinWethCap, "PR: Amount is below minimum permitted");
        require(msg.value <= perWalletMaxWethCap, "PR: Amount is above maximum permitted");
        
        addInvestor(msg.sender, msg.value);
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
            uint updatedWethValue = investors[cachedIndex[addr] - 1].wethValue + wethValue;
            require(updatedWethValue <= perWalletMaxWethCap, "PR: Max cap per wallet exceeded");
            
            investors[cachedIndex[addr] - 1].wethValue = updatedWethValue;
        }
        totalInvestedWeth += wethValue;
        emit InvestedAmount(addr, wethValue);
    }
    
    function updateCaps(uint _maxWethCap, uint _perWalletMinWethCap, uint _perWalletMaxWethCap)
        public
        onlyRole(ROLE_ADMIN)
    {
        maxWethCap = _maxWethCap;
        perWalletMinWethCap = _perWalletMinWethCap;
        perWalletMaxWethCap = _perWalletMaxWethCap;
    }
    
    function updateDefiFactoryContract(address newContract)
        public
        onlyRole(ROLE_ADMIN)
    {
        defiFactoryTokenAddress = newContract;
    }
    
    function changeState(States newState)
        private
    {
        state = newState;
        emit StateChanged(newState);
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
        require(defiFactoryTokenAddress != BURN_ADDRESS, "PR: Token address was not initialized yet!");

        wethAndTokenPairContract = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).
            getPair(defiFactoryTokenAddress, WETH_TOKEN_ADDRESS);
        
        if (wethAndTokenPairContract == BURN_ADDRESS)
        {
            wethAndTokenPairContract = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).
                createPair(defiFactoryTokenAddress, WETH_TOKEN_ADDRESS);
        }
        
        changeState(States.CreatedPair);
    }
    
    function skipSteps1()
        public
    {
        markGoalAsReached();
        prepareAddLiqudity();
        checkIfPairIsCreated();
    }
    
    function skipSteps2(uint price, uint priceDenorm, uint limit, bool isLiquidityLocked)
        public
    {
        balancePairPrice(price, priceDenorm);
        addLiquidityOnUniswapV2();
        if (isLiquidityLocked)
        {
            lockLPTokensAtTeamFinance();
        } else
        {
            uint amountOfLPTokensToSend = IWeth(wethAndTokenPairContract).balanceOf(address(this));
            IWeth(wethAndTokenPairContract).transfer(msg.sender, amountOfLPTokensToSend);
        }
        
        limit = limit == 0? investors.length: limit;
        distributeInvestorsTokens(0, limit);
    }
    
    //function balancePairPrice()
    function balancePairPrice(uint normedDeftPriceInUSD, uint PRICE_DENORM)
        public
        onlyRole(ROLE_ADMIN)
        /*view
        returns(uint,uint,uint,uint)*/
    {
        //uint normedDeftPriceInUSD = 1e12; uint PRICE_DENORM = 1e18;
        
        address wethAndUsdtPairContract = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).
            getPair(USDT_TOKEN_ADDRESS, WETH_TOKEN_ADDRESS);
        (uint usdtBalance, uint wethBalance1, ) = IUniswapV2Pair(wethAndUsdtPairContract).getReserves();
        if (USDT_TOKEN_ADDRESS > WETH_TOKEN_ADDRESS)
        {
            (usdtBalance, wethBalance1) = (wethBalance1, usdtBalance);
        }
        
        (uint deftBalance, uint wethBalance2, ) = IUniswapV2Pair(wethAndTokenPairContract).getReserves();
        if (defiFactoryTokenAddress > WETH_TOKEN_ADDRESS)
        {
            (deftBalance, wethBalance2) = (wethBalance2, deftBalance);
        }
        
        uint sqrt1 = sqrt(
                            (wethBalance2 * deftBalance * usdtBalance * PRICE_DENORM * 10**(DEFT_DECIMALS - USDT_DECIMALS)) / 
                                (normedDeftPriceInUSD * wethBalance1)
                        );
        uint sqrt2 = sqrt(
                            (wethBalance2 * deftBalance * normedDeftPriceInUSD * wethBalance1) / 
                                (usdtBalance * PRICE_DENORM * 10**(DEFT_DECIMALS - USDT_DECIMALS))
                        );
                        
        //return(sqrt1, deftBalance, sqrt2, wethBalance2);
                        
        if (sqrt1 > deftBalance)
        {
            // sell deft
            uint amountOfDeftToSell =
                (1000 * (sqrt1 - deftBalance)) / 997;
            
            IDefiFactoryToken(defiFactoryTokenAddress).mintHumanAddress(wethAndTokenPairContract, amountOfDeftToSell);
            amountOfDeftMinted += amountOfDeftToSell;
            
            uint reserveIn = deftBalance;
            uint reserveOut = wethBalance2;
            
            uint amountInWithFee = amountOfDeftToSell * 997;
            uint amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
            
            (uint amount0Out, uint amount1Out) = defiFactoryTokenAddress < WETH_TOKEN_ADDRESS? 
                (uint(0), amountOut): (amountOut, uint(0));
            
            IUniswapV2Pair(wethAndTokenPairContract).swap(
                amount0Out, 
                amount1Out, 
                address(this), 
                new bytes(0)
            );
        } else if (sqrt2 > wethBalance2)
        {
            // buy deft
            uint amountOfWethToBuy =
                (1000 * (sqrt2 - wethBalance2)) / 997;
            
            require(
                amountOfWethToBuy <= IWeth(WETH_TOKEN_ADDRESS).balanceOf(address(this)),
                "!balance_weth"
            );
            
            IWeth(WETH_TOKEN_ADDRESS).transfer(wethAndTokenPairContract, amountOfWethToBuy);
            
            uint reserveIn = wethBalance2;
            uint reserveOut = deftBalance;
            
            uint amountInWithFee = amountOfWethToBuy * 997;
            uint amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
            
            (uint amount0Out, uint amount1Out) = defiFactoryTokenAddress > WETH_TOKEN_ADDRESS? 
                (uint(0), amountOut): (amountOut, uint(0));
            
            IUniswapV2Pair(wethAndTokenPairContract).swap(
                amount0Out, 
                amount1Out, 
                address(this), 
                new bytes(0)
            );
            
            uint amountOfDustToBurn = IDefiFactoryToken(defiFactoryTokenAddress).balanceOf(address(this));
            if (amountOfDustToBurn > 0)
            {
                amountOfDeftBurned += amountOfDustToBurn;
                IDefiFactoryToken(defiFactoryTokenAddress).
                    burnHumanAddress(address(this), amountOfDustToBurn);
            }
        }
    }
    
    function addLiquidityOnUniswapV2()
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.CreatedPair, "P: Liquidity is already added!");
        
        (uint deftBalance, uint wethBalance2, ) = IUniswapV2Pair(wethAndTokenPairContract).getReserves();
        if (defiFactoryTokenAddress > WETH_TOKEN_ADDRESS)
        {
            (deftBalance, wethBalance2) = (wethBalance2, deftBalance);
        }
        
        IWeth iWeth = IWeth(WETH_TOKEN_ADDRESS);
        uint wethAmount = iWeth.balanceOf(address(this));
        iWeth.transfer(wethAndTokenPairContract, wethAmount);
        
        amountOfDeftForUniswap = (deftBalance * wethAmount) / wethBalance2;
        amountOfDeftForInvestors = amountOfDeftForUniswap + (amountOfDeftForUniswap * bonusPercent) / PERCENT_DENORM;
        
        IDefiFactoryToken(defiFactoryTokenAddress).mintHumanAddress(wethAndTokenPairContract, amountOfDeftForUniswap);
        
        IUniswapV2Pair iPair = IUniswapV2Pair(wethAndTokenPairContract);
        iPair.mint(address(this));
        
        changeState(States.AddedLiquidity);
    }

    function distributeInvestorsTokens(uint offset, uint limit)
        public
        onlyRole(ROLE_ADMIN)
    {
        require(state == States.AddedLiquidity, "PR: Tokens have already been distributed!");
        
        uint leftAmount;
        IDefiFactoryToken iDefiFactoryToken = IDefiFactoryToken(defiFactoryTokenAddress);
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
    
    function lockLPTokensAtTeamFinance()
        public
        onlyRole(ROLE_ADMIN)
    {
        IWeth(wethAndTokenPairContract).approve(TEAM_FINANCE_ADDRESS, type(uint).max);
        ITeamFinance(TEAM_FINANCE_ADDRESS).
            lockTokens(
                    wethAndTokenPairContract, 
                    _msgSender(), 
                    IWeth(wethAndTokenPairContract).balanceOf(address(this)), 
                    block.timestamp + 36500 days
                );
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
            payable(investorsList[i].addr).transfer(amountToTransfer);
        }
    }
    
    function getTotalMintedTokens()
        public
        view
        returns(uint)
    {
        return amountOfDeftForInvestors + amountOfDeftForUniswap + amountOfDeftMinted - amountOfDeftBurned;
    }
    
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
        return investors[cachedIndex[addr] - 1];
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
    
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}