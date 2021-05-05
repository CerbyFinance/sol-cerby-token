// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IValarTechToken.sol";
import "../sol-nobots-tech/INoBotsTech.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Pair.sol";
import "./IWeth.sol";
import "../sol-openzeppelin/access/AccessControlEnumerable.sol";


contract FairPresaleTech is AccessControlEnumerable {
    
    uint constant NOBOTS_TECH_CONTRACT_ID = 0;
    uint constant UNISWAP_V2_FACTORY_CONTRACT_ID = 2;
    
    address nativeToken;
    address intermediateToken;
    address usdToken;

    struct Investor {
        address addr;
        uint wethValue;
        uint sentValue;
        uint lockedUntil;
    }
    
    enum States { AcceptingPayments, ReachedGoal, PreparedAddLiqudity, CreatedPair, AddedLiquidity, DistributedTokens }
    States public state;
    
    mapping(address => uint) cachedIndex;
    Investor[] investors;
    uint public totalInvested;
    uint public totalSent;
    
    address valarTechToken = 0xef4E4770C1ec94B2aAcdC0F9705A83c93EFE3499;
    
    uint public investmentGoal = 1e30;
    uint public minInvestAmount = 1e30;
    uint public maxInvestAmount = 1e30;
    uint public amountOfTokensForInvestors;
    uint startedLocking;
    address public developerAddress;
    address public teamAddress;
    address public marketingAddress;
    address public wethAndTokenPairContract;
    
    address constant BURN_ADDRESS = address(0x0);
    
    constructor () {
        
        _setupRole(ROLE_ADMIN, _msgSender());
        
        // TODO: remove on production
        updateInvestmentSettings(
            0xd0A1E359811322d97991E03f863a0C30C2cF029C, // WETH kovan
            0x1528F3FCc26d13F7079325Fb78D9442607781c8C, // DAI kovan
            0x2F375e94FC336Cdec2Dc0cCB5277FE59CBf1cAe5, // USDC kovan
            1e15, // investmentGoal
            1e14, // minInvestAmount
            1e15, // maxInvestAmount
            developerAddress,
            teamAddress,
            marketingAddress
        );
        
        state = States.AcceptingPayments;
        
        /*
        addInvestor(msg.sender, msg.value);
        
        if (totalInvested >= investmentGoal)
        {
            state = States.ReachedGoal;
        }
        
        prepareAddLiqudity();*/
    }

    receive() external payable {
        require(state == States.AcceptingPayments, "FairPresaleTech: Accepting payments has been stopped!");
        
        addInvestor(msg.sender, msg.value);
        
        if (totalInvested >= investmentGoal)
        {
            state = States.ReachedGoal;
        }
    }
    
    function updateValarTechContract(address newContract)
        external
        onlyAdmins
    {
        valarTechToken = newContract;
    }

    function addInvestor(address addr, uint wethValue)
        internal
    {
        uint updMaxInvestAmount;
        uint lockFor;
        if (addr == developerAddress)
        {
            updMaxInvestAmount = maxInvestAmount * 30;
            lockFor = 730 days;
        } else if (addr == teamAddress)
        {
            updMaxInvestAmount = maxInvestAmount * 20;
            lockFor = 730 days;
        } else if (addr == marketingAddress) 
        {
            updMaxInvestAmount = maxInvestAmount * 10;
            lockFor = 365 days;
        } else
        {
            updMaxInvestAmount = maxInvestAmount;
            //lockFor = 60 days;
            lockFor = 10 minutes; // TODO: change on production
        }
        
        require(
            wethValue >= minInvestAmount, 
            "FairPresaleTech: Requires amount larger than _minInvestAmount!"
        );
        
        if (cachedIndex[addr] == 0)
        {
            investors.push(
                Investor(
                    addr, 
                    wethValue,
                    0,
                    block.timestamp + lockFor
                )
            );
            cachedIndex[addr] = investors.length;
        } else
        {
            investors[cachedIndex[addr] - 1].wethValue += wethValue;
        }
        require(
            investors[cachedIndex[addr] - 1].wethValue <= updMaxInvestAmount,
            "FairPresaleTech: Requires Investor max amount less than maxInvestAmount!"
        );
        
        totalInvested += wethValue;
    }
    
    modifier onlyAdmins {
        require(hasRole(ROLE_ADMIN, _msgSender()), "FairPresaleTech: !ROLE_ADMIN");
        _;
    }
    
    function updateInvestmentSettings(
        address _nativeToken, 
        address _intermediateToken, 
        address _usdToken, 
        uint _investmentGoal, 
        uint _minInvestAmount, 
        uint _maxInvestAmount,
        address _developerAddress,
        address _teamAddress,
        address _marketingAddress
    )
        public
        onlyAdmins
    {
        nativeToken = _nativeToken;
        intermediateToken = _intermediateToken;
        usdToken = _usdToken;
        investmentGoal = _investmentGoal;
        minInvestAmount = _minInvestAmount;
        maxInvestAmount = _maxInvestAmount;
        developerAddress = _developerAddress;
        teamAddress = _teamAddress;
        marketingAddress = _marketingAddress;
    }
    
    function prepareAddLiqudity()
        public
        onlyAdmins
    {
        require(state == States.ReachedGoal, "FairPresaleTech: Preparing add liquidity is completed!");
        require(address(this).balance > 0, "FairPresaleTech: Ether balance must be larger than zero!");
        
        IWeth iWeth = IWeth(nativeToken);
        iWeth.deposit{ value: address(this).balance }();
        
        state = States.PreparedAddLiqudity;
    }
    
    function createPair()
        public
        onlyAdmins
    {
        require(state == States.PreparedAddLiqudity, "FairPresaleTech: Pair is already created!");

        IUniswapV2Factory iUniswapV2Factory = IUniswapV2Factory(
            IValarTechToken(valarTechToken).
                getUtilsContractAtPos(UNISWAP_V2_FACTORY_CONTRACT_ID)
        );
        wethAndTokenPairContract = iUniswapV2Factory.getPair(valarTechToken, nativeToken);
        if (wethAndTokenPairContract == BURN_ADDRESS)
        {
            wethAndTokenPairContract = iUniswapV2Factory.createPair(valarTechToken, nativeToken);
        } else
        {
            (uint b1, uint b2,,) = getLiquidity(valarTechToken, nativeToken);
            require(b1 == 0 && b2 == 0, "FairPresaleTech: Pair already exists!");
        }
        
        INoBotsTech iNoBotsTech = INoBotsTech(
            IValarTechToken(valarTechToken).
                getUtilsContractAtPos(NOBOTS_TECH_CONTRACT_ID)
        );
        
        address[] memory whitelist = new address[](1);
        whitelist[0] = wethAndTokenPairContract;
        iNoBotsTech.bulkAddWhitelistContracts(whitelist, true, false);
        
        state = States.CreatedPair;
    }
    
    function addLiquidity()
        public
        onlyAdmins
    {
        require(state == States.CreatedPair, "FairPresaleTech: Liquidity is already added!");
        
        IWeth iWeth = IWeth(nativeToken);
        uint wethAmount = iWeth.balanceOf(address(this));
        iWeth.transfer(wethAndTokenPairContract, wethAmount);
        
        // 1e6 means 1/1e6 = $0.000001 initial price
        amountOfTokensForInvestors = getAmountToMint(wethAmount, 1e6);
        
        IValarTechToken iValarTechToken = IValarTechToken(valarTechToken);
        iValarTechToken.mintUniswapContract(wethAndTokenPairContract, amountOfTokensForInvestors);
        
        IUniswapV2Pair iPair = IUniswapV2Pair(wethAndTokenPairContract);
        iPair.mint(_msgSender()); // LP keys sent to admin, later on will be unicrypt locked for 100 years

        state = States.AddedLiquidity;
    }

    function getAmountToMint(uint amount, uint multiplier)
        public
        view
        returns (uint)
    {
        if (intermediateToken == BURN_ADDRESS)
        {
            (uint wethBalance, uint usdcBalance, uint wethDecimals, uint usdcDecimals) = getLiquidity(nativeToken, usdToken);
    
            return (amount * usdcBalance * 10**wethDecimals * multiplier) / (wethBalance * 10**usdcDecimals);
        } else
        {
            (uint wbnbBalance1, uint wethBalance1, uint wbnbDecimals1, ) = getLiquidity(nativeToken, intermediateToken);
            (uint wethBalance2, uint busdBalance2, , uint busdDecimals2) = getLiquidity(intermediateToken, usdToken);
            
            return (amount * busdBalance2 * wethBalance1 * 10**wbnbDecimals1 * multiplier) / (wethBalance2 * wbnbBalance1 * 10**busdDecimals2);
        }
    }
    
    function getLiquidity(address tokenL, address tokenR)
        internal
        view
        returns (uint, uint, uint, uint)
    {
        IUniswapV2Factory iUniswapV2Factory = IUniswapV2Factory(
            IValarTechToken(valarTechToken).
                getUtilsContractAtPos(UNISWAP_V2_FACTORY_CONTRACT_ID)
        );
        address pairContract = iUniswapV2Factory.getPair(tokenL, tokenR);
        if (BURN_ADDRESS == pairContract) return (0, 0, IWeth(tokenL).decimals(), IWeth(tokenR).decimals());
        
        (uint balanceL, uint balanceR,) = IUniswapV2Pair(pairContract).getReserves();
        if (tokenL > tokenR)
        {
            (balanceL, balanceR) =  (balanceR, balanceL);
        }
        
        return (balanceL, balanceR, IWeth(tokenL).decimals(), IWeth(tokenR).decimals());
    }

    function distributeTokens()
        external
        onlyAdmins
    {
        require(state == States.AddedLiquidity, "FairPresaleTech: Tokens have already been distributed!");
        
        INoBotsTech iNoBotsTech = INoBotsTech(
            IValarTechToken(valarTechToken).
                getUtilsContractAtPos(NOBOTS_TECH_CONTRACT_ID)
        );
        
        address[] memory whitelist = new address[](1);
        whitelist[0] = address(this);
        iNoBotsTech.bulkAddWhitelistContracts(whitelist, true, false);
        
        IValarTechToken iValarTechToken = IValarTechToken(valarTechToken);
        iValarTechToken.mintHumanAddress(address(this), amountOfTokensForInvestors);
        
        startedLocking = block.timestamp;
        
        state = States.DistributedTokens;
    }
    
    function claimVestingTokensByList(uint offset, uint limit)
        public
    {
        Investor[] memory invs = listInvestors(offset, limit);
        for(uint i = 0; i < invs.length; i++)
        {
            claimVestingTokens(invs[i].addr);
        }
    }
    
    function claimVestingTokens(address addr)
        public
    {
        if (addr == BURN_ADDRESS) addr = msg.sender;
        
        uint claimableAmount = getClaimableTokenAmount(addr);
        if (claimableAmount == 0) return;
        
        investors[cachedIndex[addr] - 1].sentValue += claimableAmount;
        
        IValarTechToken iValarTechToken = IValarTechToken(valarTechToken);
        iValarTechToken.transferFromVestingContract(addr, claimableAmount);
    }
    
    function getClaimableTokenAmount(address addr)
        public
        view
        returns(uint)
    {
        require(state == States.DistributedTokens, "FairPresaleTech: Tokens aren't distributed yet!");
        
        if (addr == BURN_ADDRESS) addr = msg.sender;
        Investor memory investor = investors[cachedIndex[addr] - 1];
        uint nominator = block.timestamp < investor.lockedUntil? 
            block.timestamp - startedLocking: 1;
        uint denominator = block.timestamp < investor.lockedUntil? 
            investor.lockedUntil - startedLocking: 1;
            
            
        // TODO: use balanceOf
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
        require(state == States.DistributedTokens, "FairPresaleTech: Tokens aren't distributed yet!");
        
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
}