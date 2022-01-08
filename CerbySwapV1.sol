// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.11;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./openzeppelin/security/ReentrancyGuard.sol";
import "./openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ICerbyTokenMinterBurner.sol";
import "./interfaces/ICerbyCronJobs.sol";
import "./interfaces/ICerbyBotDetection.sol";
import "./interfaces/ICerbySwapLP1155V1.sol";
import "./CerbyCronJobsExecution.sol";

struct Pool {
    address token;
    uint112 balanceToken;
    uint112 balanceCerUsd;
    uint16 fee;
}

contract CerbySwapV1 is AccessControlEnumerable, ReentrancyGuard, CerbyCronJobsExecution {
    using SafeERC20 for IERC20;

    Pool[] pools;
    mapping(address => uint) tokenToPoolPosition;

    address constant testUsdcToken = 0xC7a0e9429BBc262d97f3e87BF38a95cAE8b05EDa;
    address constant testCerbyToken = 0x029581a9121998fcBb096ceafA92E3E10057878f;
    address constant cerUsdToken = 0xA84d62F776606B9eEbd761E2d31F65442eCc437E;
    address constant lpErc1155V1 = 0x8e06e97c598B0Bb2910Df62C626EBf6cd55409e6;
    uint16 constant FEE_MIN_VALUE = 9900;
    uint16 constant FEE_MAX_VALUE = 10000;
    uint16 constant NORMAL_FEE = 9985; // 0.15% per transaction XXX <--> cerUSD
    uint16 constant STABLECOIN_FEE = 9995; // 0.05% per transaction USDC <--> cerUSD

    uint constant MINIMUM_LIQUIDITY = 1000;
    address constant DEAD_ADDRESS = address(0xdead);

    bool isInitializedAlready;

    constructor() {
        _setupRole(ROLE_ADMIN, msg.sender);
    }

    function initialize() 
        public
    {
        require(!isInitializedAlready, "CS1: Already initialized");
        isInitializedAlready = true;

        // Filling with empty pool 0th position
        pools.push(Pool(
            address(0),
            0,
            0,
            0
        ));
        ICerbySwapLP1155V1(lpErc1155V1).ownerMint(
            DEAD_ADDRESS,
            0,
            MINIMUM_LIQUIDITY,
            ""
        );

        adminCreatePool(
            testCerbyToken,
            1e18 * 1e6,
            1e18 * 3e5,
            NORMAL_FEE
        );

        adminCreatePool(
            testUsdcToken,
            1e18 * 1e6,
            1e18 * 1e6,
            STABLECOIN_FEE
        );
    }

    modifier tokenMustExistInPool(address token)
    {
        require(
            tokenToPoolPosition[token] > 0 && token != cerUsdToken,
            "CS1: Wrong token"
        );
        _;
    }

    modifier tokenDoesNotExistInPool(address token)
    {
        require(
            tokenToPoolPosition[token] == 0 && token != cerUsdToken,
            "CS1: Token exists"
        );
        _;
    }

    modifier transactionIsNotExpired(uint expireTimestamp)
    {
        require(
            block.timestamp <= expireTimestamp,
            "CS1: Transaction is expired"
        );
        _;
    }

    modifier poolMustBeSynced(address token)
    {
        _syncTokenBalanceInPool(token);
        _;
    }

    modifier safeTransferTokensNeeded(address token, uint amount)
    {
        uint oldBalance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint newBalance = IERC20(token).balanceOf(address(this));
        require(
            newBalance >= oldBalance + amount,
            "CS1: Fee-on-transfer tokens aren't supported"
        );
        _;
    }

    modifier feeIsInNormalRange(uint16 fee)
    {
        require(
            FEE_MIN_VALUE <= fee &&
            fee < FEE_MAX_VALUE,
            "CS1: Fee must be in range 0.01% - 1.00%"
        );
        _;
    }

    // TODO: add remove pool or disable pool to allow remove liquidity only
    // TODO: adminCreatePool, disable/enable userCreatePool
    // TODO: check if debit is negative do we allow buys/sells???
    function adminCreatePool(address token, uint112 addTokenAmount, uint112 mintCerUsdAmount, uint16 fee)
        public
        nonReentrant()
        feeIsInNormalRange(fee)
        tokenDoesNotExistInPool(token)
        safeTransferTokensNeeded(token, addTokenAmount)
    {
        ICerbyTokenMinterBurner(cerUsdToken).mintHumanAddress(address(this), mintCerUsdAmount);

        {
            Pool memory pool = Pool(
                token,
                addTokenAmount,
                mintCerUsdAmount,
                fee
            );
            pools.push(pool);
            tokenToPoolPosition[token] = pools.length - 1;
        }

        ICerbySwapLP1155V1(lpErc1155V1).ownerMint(
            DEAD_ADDRESS,
            pools.length - 1,
            MINIMUM_LIQUIDITY,
            ""
        );

        uint lpAmount = sqrt(uint(addTokenAmount) * uint(mintCerUsdAmount)) - MINIMUM_LIQUIDITY;
        ICerbySwapLP1155V1(lpErc1155V1).ownerMint(
            msg.sender,
            pools.length - 1,
            lpAmount,
            ""
        );

        _syncTokenBalanceInPool(token);
    }

    function addTokenLiquidity(address token, uint112 addTokenAmount)
        public
        //executeCronJobs() TODO: enable on production
        nonReentrant()
        tokenMustExistInPool(token)
        poolMustBeSynced(token)
        safeTransferTokensNeeded(token, addTokenAmount)
    {
        uint poolPos = tokenToPoolPosition[token];
        uint112 mintCerUsdAmount = uint112(
            (uint(addTokenAmount) * uint(pools[poolPos].balanceCerUsd)) / uint(pools[poolPos].balanceToken)
        );
        ICerbyTokenMinterBurner(cerUsdToken).mintHumanAddress(address(this), mintCerUsdAmount);

        uint totalLPSupply = ICerbySwapLP1155V1(lpErc1155V1).totalSupply(poolPos);
        uint lpAmount = (addTokenAmount * totalLPSupply) / pools[poolPos].balanceToken;
        ICerbySwapLP1155V1(lpErc1155V1).ownerMint(
            msg.sender,
            poolPos,
            lpAmount,
            ""
        );

        pools[poolPos].balanceToken += addTokenAmount;
        pools[poolPos].balanceCerUsd += mintCerUsdAmount;

        _syncTokenBalanceInPool(token);
    }

    function removeTokenLiquidity(address token, uint removeLpAmount)
        public
        //executeCronJobs() TODO: enable on production
        nonReentrant()
        tokenMustExistInPool(token)
        poolMustBeSynced(token)
    {
        uint poolPos = tokenToPoolPosition[token];
        ICerbySwapLP1155V1(lpErc1155V1).ownerBurn(msg.sender, poolPos, removeLpAmount);

        uint totalLPSupply = ICerbySwapLP1155V1(lpErc1155V1).totalSupply(poolPos);
        uint112 removeTokenAmount = uint112(
            (uint(pools[poolPos].balanceToken) * removeLpAmount) / totalLPSupply
        );

        uint112 burnCerUsdAmount = uint112(
            (uint(pools[poolPos].balanceCerUsd) * removeLpAmount) / totalLPSupply
        );
        ICerbyTokenMinterBurner(cerUsdToken).burnHumanAddress(address(this), burnCerUsdAmount);

        pools[poolPos].balanceToken -= removeTokenAmount;
        pools[poolPos].balanceCerUsd -= burnCerUsdAmount;

        _syncTokenBalanceInPool(token);
    }

    // TODO: add swapTokenToExactCerUSD XXX --> cerUSD
    // TODO: add swapCerUsdToExactToken cerUSD --> YYY
    // TODO: add swapTokenToExactToken XXX --> cerUSD --> YYY (XXX != YYY)

    function swapExactTokenForToken(
        address tokenIn,
        address tokenOut,
        uint112 amountTokenIn,
        uint112 minAmountTokenOut,
        uint32 expireTimestamp
    )
        public
        //executeCronJobs() TODO: enable on production
        nonReentrant()
        transactionIsNotExpired(expireTimestamp)
        tokenMustExistInPool(tokenIn)
        poolMustBeSynced(tokenIn)
        returns (uint112)
    {
        uint112 amountCerUsdIn = _swapExactTokenToCerUsd(
            tokenIn,
            amountTokenIn,
            0,
            false
        );
        uint112 outputTokenOut = _swapExactCerUsdForToken(
            tokenOut,
            amountCerUsdIn,
            minAmountTokenOut,
            false
        );
        return outputTokenOut;
    }

    
    // "0x029581a9121998fcBb096ceafA92E3E10057878f", "997503992263724670916", 0, "2041564156"
    // "0xC7a0e9429BBc262d97f3e87BF38a95cAE8b05EDa", "1000000000000000000000", 0, "2041564156"
    // "0x029581a9121998fcBb096ceafA92E3E10057878f","0xC7a0e9429BBc262d97f3e87BF38a95cAE8b05EDa","10000000000000000000000","0","2041564156"
    // "0xC7a0e9429BBc262d97f3e87BF38a95cAE8b05EDa","0x029581a9121998fcBb096ceafA92E3E10057878f","1000000000000000000000","0","2041564156"
    function swapExactTokenToCerUsd(
        address tokenIn,
        uint112 amountTokenIn,
        uint112 minAmountCerUsdOut,
        uint32 expireTimestamp
    )
        public
        //executeCronJobs() TODO: enable on production
        nonReentrant()
        transactionIsNotExpired(expireTimestamp)
        tokenMustExistInPool(tokenIn)
        poolMustBeSynced(tokenIn)
        returns (uint112)
    {
        return _swapExactTokenToCerUsd(
            tokenIn,
            amountTokenIn,
            minAmountCerUsdOut,
            true
        );
    }

    function _swapExactTokenToCerUsd(
        address tokenIn,
        uint112 amountTokenIn,
        uint112 minAmountCerUsdOut,
        bool enableInternalCerUsdTransfers
    )
        private
        safeTransferTokensNeeded(tokenIn, amountTokenIn)
        returns (uint112)
    {
        uint poolPos = tokenToPoolPosition[tokenIn];
        uint112 increaseTokenBalance = 
            uint112(IERC20(tokenIn).balanceOf(address(this))) - pools[poolPos].balanceToken;

        uint112 outputCerUsdAmount = uint112(getOutputExactTokensForCerUsd(poolPos, increaseTokenBalance));
        require(
            outputCerUsdAmount >= minAmountCerUsdOut,
            "CS1: Output amount less than minimum specified"
        );


        uint oldKValue = uint(pools[poolPos].balanceToken) * uint(pools[poolPos].balanceCerUsd);
        pools[poolPos].balanceCerUsd -= outputCerUsdAmount;
        pools[poolPos].balanceToken += amountTokenIn;

        if (enableInternalCerUsdTransfers) {
            IERC20(cerUsdToken).transfer(msg.sender, outputCerUsdAmount);
        }

        updateTokenBalanceAndCheckKValue(poolPos, tokenIn, oldKValue);

        return outputCerUsdAmount;
    }

    function swapExactCerUsdForToken(
        address tokenOut,
        uint112 amountCerUsdIn,
        uint112 minAmountTokenOut,
        uint32 expireTimestamp
    )
        public
        //executeCronJobs() TODO: enable on production
        nonReentrant()
        tokenMustExistInPool(tokenOut)
        poolMustBeSynced(tokenOut)
        transactionIsNotExpired(expireTimestamp)
        returns (uint112)
    {
        return _swapExactCerUsdForToken(
            tokenOut,
            amountCerUsdIn,
            minAmountTokenOut,
            true
        );
    }

    function _swapExactCerUsdForToken(
        address tokenOut,
        uint112 amountCerUsdIn,
        uint112 minAmountTokenOut,
        bool enableInternalCerUsdTransfers
    )
        private
        returns (uint112)
    {
        if (enableInternalCerUsdTransfers) {
            IERC20(cerUsdToken).transferFrom(msg.sender, address(this), amountCerUsdIn);
        }

        uint poolPos = tokenToPoolPosition[tokenOut];

        uint112 outputTokenAmount = uint112(getOutputExactCerUsdForToken(poolPos, amountCerUsdIn));
        require(
            outputTokenAmount >= minAmountTokenOut,
            "CS1: Output amount less than minimum specified"
        );

        uint oldKValue = uint(pools[poolPos].balanceToken) * uint(pools[poolPos].balanceCerUsd);
        pools[poolPos].balanceCerUsd += amountCerUsdIn;
        pools[poolPos].balanceToken -= outputTokenAmount;

        IERC20(tokenOut).safeTransfer(msg.sender, outputTokenAmount);

        updateTokenBalanceAndCheckKValue(poolPos, tokenOut, oldKValue);

        return outputTokenAmount;
    }

    function updateTokenBalanceAndCheckKValue(uint poolPos, address token, uint oldKValue)
        private
    {
        uint112 newBalanceToken = uint112(IERC20(token).balanceOf(address(this)));
        uint newKValue = uint(newBalanceToken) * uint(pools[poolPos].balanceCerUsd);
        require(
            newKValue >= oldKValue,
            "CS1: K value decreased"
        );
        
        if (newBalanceToken != pools[poolPos].balanceToken)
        {
            pools[poolPos].balanceToken = newBalanceToken;
        }
    }

    function adminUpdateFee(address token, uint16 newFee)
        public
        onlyRole(ROLE_ADMIN)
        feeIsInNormalRange(newFee)
        tokenMustExistInPool(token)
        poolMustBeSynced(token)
    {
        uint poolPos = tokenToPoolPosition[token];
        pools[poolPos].fee = newFee;
    }

    function syncTokenBalanceInPool(address token)
        public
        tokenMustExistInPool(token)
        //executeCronJobs() TODO: enable on production
    {
        _syncTokenBalanceInPool(token);        
    }

    function _syncTokenBalanceInPool(address token)
        private
    {
        uint poolPos = tokenToPoolPosition[token];
        uint112 newBalanceToken = uint112(IERC20(token).balanceOf(address(this)));
        if (newBalanceToken != pools[poolPos].balanceToken)
        {
            pools[poolPos].balanceToken = newBalanceToken;
        }
    }

    function getOutputExactTokensForCerUsd(uint poolPos, uint increaseTokenBalance)
        public
        view
        returns (uint)
    {
        return _getOutput(
            increaseTokenBalance,
            pools[poolPos].balanceToken,
            pools[poolPos].balanceCerUsd,
            pools[poolPos].fee
        );
    }

    function getOutputExactCerUsdForToken(uint poolPos, uint increaseCerUsdBalance)
        public
        view
        returns (uint)
    {
        return _getOutput(
            increaseCerUsdBalance,
            pools[poolPos].balanceCerUsd,
            pools[poolPos].balanceToken,
            pools[poolPos].fee
        );
    }

    function _getOutput(uint amountIn, uint reservesIn, uint reservesOut, uint poolFee)
        private
        pure
        returns (uint)
    {
        uint amountInWithFee = amountIn * poolFee;
        uint amountOut = 
            (reservesOut * amountInWithFee) / (reservesIn * FEE_MAX_VALUE + amountInWithFee);
        return amountOut;
    }

    function getPoolByPosition(uint pos)
        public
        view
        returns (Pool memory)
    {
        return pools[pos];
    }

    function getPoolByToken(address token)
        public
        view
        returns (Pool memory)
    {
        return pools[tokenToPoolPosition[token]];
    }

    function sqrt(uint x)
        private
        pure
        returns (uint y) 
    {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function testGetPrices()
        public
        view
        returns (uint, uint)
    {
        uint poolPos1 = tokenToPoolPosition[testCerbyToken];
        uint poolPos2 = tokenToPoolPosition[testUsdcToken];
        return (
            (uint(pools[poolPos1].balanceCerUsd) * 1e18) / uint(pools[poolPos1].balanceToken),
            (uint(pools[poolPos2].balanceCerUsd) * 1e18) / uint(pools[poolPos2].balanceToken)            
        );
    }

    function testGetBalances()
        public
        view
        returns (uint, uint, uint)
    {
        return (
            IERC20(testCerbyToken).balanceOf(address(this)),
            IERC20(testUsdcToken).balanceOf(address(this)),
            IERC20(cerUsdToken).balanceOf(address(this))
        );
    }

    function testGetPools()
        public
        view
        returns (Pool memory, Pool memory)
    {
        uint poolPos1 = tokenToPoolPosition[testCerbyToken];
        uint poolPos2 = tokenToPoolPosition[testUsdcToken];
        return (
            pools[poolPos1],
            pools[poolPos2]
        );
    }
}