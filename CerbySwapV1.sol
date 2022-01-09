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


contract CerbySwapV1 is AccessControlEnumerable, ReentrancyGuard, CerbyCronJobsExecution {
    using SafeERC20 for IERC20;

    Pool[] pools;
    mapping(address => uint) tokenToPoolPosition;

    /* KOVAN 
    // "0x37E140032ac3a8428ed43761a9881d4741Eb3a73", "997503992263724670916", 0, "2041564156"
    // "0x14769F96e57B80c66837701DE0B43686Fb4632De", "1000000000000000000000", 0, "2041564156"
    // "0x37E140032ac3a8428ed43761a9881d4741Eb3a73","0x14769F96e57B80c66837701DE0B43686Fb4632De","10000000000000000000000","0","2041564156"
    // "0x14769F96e57B80c66837701DE0B43686Fb4632De","0x37E140032ac3a8428ed43761a9881d4741Eb3a73","1000000000000000000000","0","2041564156"
    
    address constant lpErc1155V1 = 0x5DEBC34b9619B258d36a7816641dFF2833fFa30c;
    address constant testCerbyToken = 0x3d982cB3BC8D1248B17f22b567524bF7BFFD3b11;
    address constant cerUsdToken = 0x37E140032ac3a8428ed43761a9881d4741Eb3a73;
    address constant testUsdcToken = 0x14769F96e57B80c66837701DE0B43686Fb4632De;*/

    /* Localhost
    // "0xde402E9D305bAd483d47bc858cC373c5a040A62D", "997503992263724670916", 0, "2041564156"
    // "0xCd300dd54345F48Ba108Df3D792B6c2Dbb17edD2", "1000000000000000000000", 0, "2041564156"
    // "0xCd300dd54345F48Ba108Df3D792B6c2Dbb17edD2","0xde402E9D305bAd483d47bc858cC373c5a040A62D","10000000000000000000000","0","2041564156"
    // "0xde402E9D305bAd483d47bc858cC373c5a040A62D","0xCd300dd54345F48Ba108Df3D792B6c2Dbb17edD2","1000000000000000000000","0","20415641
    */
    address constant lpErc1155V1 = 0xE94EFBCaA00665C8faA47E18741DA9f212a15c20;
    address constant testCerbyToken = 0xCd300dd54345F48Ba108Df3D792B6c2Dbb17edD2;
    address constant cerUsdToken = 0x04D7000CC826349A872757D82b3E0F68a713B3c5;
    address constant testUsdcToken = 0xde402E9D305bAd483d47bc858cC373c5a040A62D;

    uint16 constant FEE_DENORM = 10000;

    uint constant NUMBER_OF_4HOUR_INTERVALS = 8;
    uint constant MINIMUM_LIQUIDITY = 1000;
    address constant DEAD_ADDRESS = address(0xdead);

    bool isInitializedAlready;

    struct Pool {
        address token;
        uint112 balanceToken;
        uint112 balanceCerUsd;
        uint32[NUMBER_OF_4HOUR_INTERVALS] hourlyTradeVolumeInCerUsd;
    }

    constructor() {
        _setupRole(ROLE_ADMIN, msg.sender);

        initialize(); // TODO: Remove on production. Must not do any mints in contract creation!
    }

    function initialize() 
        public
    {
        require(!isInitializedAlready, "CS1: Already initialized");
        isInitializedAlready = true;


        // Filling with empty pool 0th position
        uint32[NUMBER_OF_4HOUR_INTERVALS] memory hourlyTradeVolumeInCerUsd;
        pools.push(Pool(
            address(0),
            0,
            0,
            hourlyTradeVolumeInCerUsd
        ));
        ICerbySwapLP1155V1(lpErc1155V1).adminMint(
            DEAD_ADDRESS,
            0,
            MINIMUM_LIQUIDITY,
            ""
        );

        adminCreatePool(
            testCerbyToken,
            1e18 * 1e6,
            1e18 * 3e5
        );

        adminCreatePool(
            testUsdcToken,
            1e18 * 1e6,
            1e18 * 1e6
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

    function adminCreatePool(address token, uint112 addTokenAmount, uint112 mintCerUsdAmount)
        public
        onlyRole(ROLE_ADMIN)
        nonReentrant()
        tokenDoesNotExistInPool(token)
        safeTransferTokensNeeded(token, addTokenAmount)
    {
        ICerbyTokenMinterBurner(cerUsdToken).mintHumanAddress(address(this), mintCerUsdAmount);

        {
            uint32[NUMBER_OF_4HOUR_INTERVALS] memory hourlyTradeVolumeInCerUsd;
            Pool memory pool = Pool(
                token,
                addTokenAmount,
                mintCerUsdAmount,
                hourlyTradeVolumeInCerUsd
            );
            pools.push(pool);
            tokenToPoolPosition[token] = pools.length - 1;
        }

        ICerbySwapLP1155V1(lpErc1155V1).adminMint(
            DEAD_ADDRESS,
            pools.length - 1,
            MINIMUM_LIQUIDITY,
            ""
        );

        uint lpAmount = sqrt(uint(addTokenAmount) * uint(mintCerUsdAmount)) - MINIMUM_LIQUIDITY;
        ICerbySwapLP1155V1(lpErc1155V1).adminMint(
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
        ICerbySwapLP1155V1(lpErc1155V1).adminMint(
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
        ICerbySwapLP1155V1(lpErc1155V1).adminBurn(msg.sender, poolPos, removeLpAmount);

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
        {
            uint current4Hour = getCurrent4Hour();
            uint next4Hour = (current4Hour + 1) % NUMBER_OF_4HOUR_INTERVALS;
            pools[poolPos].balanceCerUsd -= outputCerUsdAmount;
            pools[poolPos].balanceToken += amountTokenIn;
            unchecked {
                pools[poolPos].hourlyTradeVolumeInCerUsd[current4Hour] += uint32(outputCerUsdAmount / 1e18);
            }
            if (pools[poolPos].hourlyTradeVolumeInCerUsd[next4Hour] > 0)
            {
                pools[poolPos].hourlyTradeVolumeInCerUsd[next4Hour] = 0;
            }
        }

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

        uint current4Hour = getCurrent4Hour();
        uint next4Hour = (getCurrent4Hour() + 1) % pools[poolPos].hourlyTradeVolumeInCerUsd.length;
        uint oldKValue = uint(pools[poolPos].balanceToken) * uint(pools[poolPos].balanceCerUsd);
        pools[poolPos].balanceCerUsd += amountCerUsdIn;
        pools[poolPos].balanceToken -= outputTokenAmount;

        unchecked {
            pools[poolPos].hourlyTradeVolumeInCerUsd[current4Hour] += uint32(amountCerUsdIn / 1e18);
        }
        if (pools[poolPos].hourlyTradeVolumeInCerUsd[next4Hour] > 0)
        {
            pools[poolPos].hourlyTradeVolumeInCerUsd[next4Hour] = 0;
        }

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

    function getCurrent4Hour()
        public
        view
        returns (uint)
    {
        return (block.timestamp / 14400) % NUMBER_OF_4HOUR_INTERVALS;
    }

    function getCurrentFeeBasedOnTrades(uint poolPos)
        public
        view
        returns (uint fee)
    {
        uint current4Hour = getCurrent4Hour();
        uint next4Hour = (current4Hour + 1) % NUMBER_OF_4HOUR_INTERVALS;
        uint last24HourTradeVolumeInCerUSD;
        for(uint i; i<NUMBER_OF_4HOUR_INTERVALS; i++)
        {
            if (i == current4Hour || i == next4Hour) continue;

            last24HourTradeVolumeInCerUSD += pools[poolPos].hourlyTradeVolumeInCerUsd[i];
        }

        // TVL x0.15 ---> 1.00%
        // TVL x0.15 - x15 ---> 1.00% - 0.01%
        // TVL x15 ---> 0.01%
        uint volumeMultiplied = last24HourTradeVolumeInCerUSD * 1e18 * 1000;
        uint TVLMultiplied = pools[poolPos].balanceCerUsd * 2 * 150; // x2 because two tokens in pair
        if (volumeMultiplied <= TVLMultiplied) {
            fee = 9900;
        } else if (TVLMultiplied < volumeMultiplied && volumeMultiplied < 100 * TVLMultiplied) {
            fee = 9900 + (volumeMultiplied - TVLMultiplied) / TVLMultiplied;
        } else if (volumeMultiplied > 100 * TVLMultiplied)
        {
            fee = 9999;
        }

        return fee;
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
            getCurrentFeeBasedOnTrades(poolPos)
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
            getCurrentFeeBasedOnTrades(poolPos)
        );
    }

    function _getOutput(uint amountIn, uint reservesIn, uint reservesOut, uint poolFee)
        private
        pure
        returns (uint)
    {
        uint amountInWithFee = amountIn * poolFee;
        uint amountOut = 
            (reservesOut * amountInWithFee) / (reservesIn * FEE_DENORM + amountInWithFee);
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