// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.11;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/ICerbyTokenMinterBurner.sol";
import "./interfaces/ICerbySwapLP1155V1.sol";
import "./interfaces/IERC20.sol";
import "./CerbyCronJobsExecution.sol";
import "./CerbySwapLP1155V1.sol";


contract CerbySwapV1 is CerbySwapLP1155V1 {

    struct ErrorsList {
        string ALREADY_INITIALIZED_A;
        string TOKEN_ALREAD_EXISTS_B;
        string TOKEN_DOES_NOT_EXIST_C;
        string TRANSACTION_IS_EXPIRED_D;
        string FEE_ON_TRANSFER_TOKENS_ARENT_SUPPORTED_E;
        string AMOUNT_OF_TOKENS_MUST_BE_LARGER_THAN_ONE_F;
        string MSG_VALUE_PROVIDED_MUST_BE_ZERO_G;
        string OUTPUT_CERUSD_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_H;
        string OUTPUT_TOKENS_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_i;
        string INPUT_CERUSD_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_J;
        string INPUT_TOKENS_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_K;
        string SWAP_TOKEN_TO_SAME_TOKEN_IS_FORBIDDEN_L;
        string ONE_OF_TOKENIN_OR_TOKEN_OUT_IS_WRONG_M;
        string POOL_ID_DOES_NOT_EXIST_N;
        string AMOUNT_OF_CERUSD_OR_TOKENS_MUST_BE_LARGER_THAN_ONE_O;
        string INVARIANT_K_VALUE_MUST_BE_INCREASED_ON_ANY_TRADE_P;
        string SAFE_TRANSFER_NATIVE_FAILED_Q;
        string SAFE_TRANSFER_FAILED_R;
        string SAFE_TRANSFER_FROM_FAILED_S;
        string MSG_VALUE_PROVIDED_MUST_BE_LARGER_THAN_AMOUNT_IN_T;
        string AMOUNT_OF_CERUSD_MUST_BE_LARGER_THAN_ONE_U;
        string RESERVES_IN_AND_OUT_MUST_BE_LARGER_THAN_1000_V;
        string TRANSACTION_IS_TEMPORARILY_DISABLED_W;
        string FEE_IS_WRONG_X;
        string TVL_MULTIPLIER_IS_WRONG_Y;
    }

    ErrorsList errorsList;

    Pool[] pools;
    mapping(address => uint) tokenToPoolId;
    uint totalCerUsdBalance;

    /* KOVAN 
    // "0x37E140032ac3a8428ed43761a9881d4741Eb3a73", "997503992263724670916", 0, "2041564156"
    // "0x14769F96e57B80c66837701DE0B43686Fb4632De", "1000000000000000000000", 0, "2041564156"
    // "0x37E140032ac3a8428ed43761a9881d4741Eb3a73","0x14769F96e57B80c66837701DE0B43686Fb4632De","10000000000000000000000","0","2041564156"
    // "0x14769F96e57B80c66837701DE0B43686Fb4632De","0x37E140032ac3a8428ed43761a9881d4741Eb3a73","1000000000000000000000","0","2041564156"
    
    address testCerbyToken = 0x3d982cB3BC8D1248B17f22b567524bF7BFFD3b11;
    address cerUsdToken = 0x37E140032ac3a8428ed43761a9881d4741Eb3a73;
    address testUsdcToken = 0xD575ef966cfE21a5a5602dFaDAd3d1cAe8C60fDB;
    address testCerbyBotDetectionContract;*/

    /* Localhost
    // "0xde402E9D305bAd483d47bc858cC373c5a040A62D", "997503992263724670916", 0, "2041564156"
    // "0xCd300dd54345F48Ba108Df3D792B6c2Dbb17edD2", "1000000000000000000000", 0, "2041564156"
    // "0xF3B07F8167b665BA3E2DD29c661DeE3a1da2380a","0x2c4fE51d1Ad5B88cD2cc2F45ad1c0C857f06225e","1000000000000000000000","0","20415641000","0x539FaA851D86781009EC30dF437D794bCd090c8F"
    // "0x2c4fE51d1Ad5B88cD2cc2F45ad1c0C857f06225e","0xF3B07F8167b665BA3E2DD29c661DeE3a1da2380a","1000000000000000000000","0","20415641000","0x539FaA851D86781009EC30dF437D794bCd090c8F"
    1000000000000000000011 494510434669677019755 489223177884861877370
    2047670051318999350473 1000000000000000000011
    */

    address testCerbyToken = 0xE7126C0Fb4B1f5F79E5Bbec3948139dCF348B49C; // TODO: remove on production
    address cerUsdToken = 0xF690ea79833E2424b05a1d0B779167f5BE763268; // TODO: make constant
    address testUsdcToken = 0x7412F2cD820d1E63bd130B0FFEBe44c4E5A47d71; // TODO: remove on production
    
    address nativeToken = 0x14769F96e57B80c66837701DE0B43686Fb4632De;

    // mint fees = (fees * MINT_FEE_DENORM) / (mintFeeMultiplier + MINT_FEE_DENORM); 
    // mintFeeMultiplier = 4*MINT_FEE_DENORM --> fees = 1/5 or 20% of all fees
    // mintFeeMultiplier = 0 disables mint fees
    uint constant MINT_FEE_DENORM = 100;
    
    uint constant FEE_DENORM = 10000;
    uint constant TRADE_VOLUME_DENORM = 10 * 1e18;

    uint constant TVL_MULTIPLIER_DENORM = 10000;  

    // 6 4hours + 1 current 4hour + 1 next 4hour = 26 hours
    uint constant NUMBER_OF_TRADE_PERIODS = 8; 
    uint constant ONE_PERIOD_IN_SECONDS = 240 minutes;

    uint constant MINIMUM_LIQUIDITY = 1000;
    address constant DEAD_ADDRESS = address(0xdead);

    Settings public settings;

    struct Settings {
        address feeToBeneficiary;
        uint mintFeeMultiplier;
        uint feeMinimum;
        uint feeMaximum;
        uint tvlMultiplierMinimum;
        uint tvlMultiplierMaximum;
    }

    struct Pool {
        address token;
        uint32[NUMBER_OF_TRADE_PERIODS] tradeVolumePerPeriodInCerUsd;
        uint128 balanceToken;
        uint128 balanceCerUsd;
        uint128 lastSqrtKValue;
    }


    event PairCreated(
        address token,
        uint poolId
    );
    event LiquidityAdded(
        address token, 
        uint amountTokensIn, 
        uint amountCerUsdToMint, 
        uint lpAmount
    );
    event LiquidityRemoved(
        address token, 
        uint amountTokensOut, 
        uint amountCerUsdToBurn, 
        uint amountLpTokensBalanceToBurn
    );
    event Swap(
        address token,
        address sender, 
        uint amountTokensIn, 
        uint amountCerUsdIn, 
        uint amountTokensOut, 
        uint amountCerUsdOut,
        uint currentOneMinusFee,
        address transferTo
    );
    event Sync(
        address token, 
        uint newBalanceToken, 
        uint newBalanceCerUsd
    );

    constructor() {
        _setupRole(ROLE_ADMIN, msg.sender);
        errorsList = 
            ErrorsList(
                "A", "B", "C", "D", "E", "F", "G", "H", "i", "J", "K", "L", "M", "N", 
                "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y"
            );

        settings = Settings(
            address(0xdead123), // feeToBeneficiary TODO: update on production
            0, // TODO: update on production = 4 * MINT_FEE_DENORM, // mintFeeMultiplier 1/5 of fees goes to treasury
            1, // feeMinimum = 0.01%
            100, // feeMaximum = 1.00%
            (TVL_MULTIPLIER_DENORM * 15) / 100, // tvlMultiplierMinimum = TVL * 0.15
            TVL_MULTIPLIER_DENORM * 15 // tvlMultiplierMaximum = TVL * 15
        );

        // Filling with empty pool 0th id
        uint32[NUMBER_OF_TRADE_PERIODS] memory tradeVolumePerPeriodInCerUsd;
        pools.push(Pool(
            address(0),
            tradeVolumePerPeriodInCerUsd,
            0,
            0,
            0
        ));

        // TODO: fill weth, wbnb, wmatic etc
        if (block.chainid == 12345) {
            nativeToken = DEAD_ADDRESS;
        } else if (block.chainid == 98765) {
            nativeToken = DEAD_ADDRESS;
        } 

        nativeToken = 0x14769F96e57B80c66837701DE0B43686Fb4632De; // TODO: update
    }

    receive() external payable {}

    modifier tokenMustExistInPool(address token)
    {
        require(
            tokenToPoolId[token] > 0 && token != cerUsdToken,
            errorsList.TOKEN_DOES_NOT_EXIST_C
        );
        _;
    }

    modifier tokenDoesNotExistInPool(address token)
    {
        require(
            tokenToPoolId[token] == 0 && token != cerUsdToken,
            errorsList.TOKEN_ALREAD_EXISTS_B
        );
        _;
    }

    modifier transactionIsNotExpired(uint expireTimestamp)
    {
        require(
            block.timestamp <= expireTimestamp,
            errorsList.TRANSACTION_IS_EXPIRED_D
        );
        _;
    }

    function getTokenToPoolId(address token) 
        public
        view
        returns (uint)
    {
        return tokenToPoolId[token];
    }

    // TODO: remove on production
    function testSetupTokens(address , address _testCerbyToken, address _cerUsdToken, address _testUsdcToken, address )
        public
    {
        //testCerbyBotDetectionContract = _testCerbyBotDetectionContract;
        testCerbyToken = _testCerbyToken;
        cerUsdToken = _cerUsdToken;
        testUsdcToken = _testUsdcToken;
        
        testInit();
    }

    // TODO: remove on production
    function testInit()
        public
    {
        // TODO: remove on production
        adminCreatePool(
            testCerbyToken,
            1e18 * 1e6,
            1e18 * 5e5,
            msg.sender
        );

        // TODO: remove on production
        adminCreatePool(
            testUsdcToken,
            1e18 * 7e5,
            1e18 * 7e5,
            msg.sender
        );
    }

    // TODO: remove on production
    function adminInitialize() 
        public
        payable
        // onlyRole(ROLE_ADMIN) // TODO: enable on production
    {        

        // TODO: remove on production
        adminCreatePool(
            nativeToken,
            1e15,
            1e18 * 1e6,
            msg.sender
        );
    }
    
    function adminUpdateFeesAndTvlMultipliers(
        Settings calldata _settings
    )
        public
        onlyRole(ROLE_ADMIN)
    {
        require(
            0 < _settings.feeMinimum &&
            _settings.feeMinimum < _settings.feeMaximum &&
            _settings.feeMaximum < 500, // 5.00% is hard limit on updating fee
            errorsList.FEE_IS_WRONG_X
        );
        require(
            _settings.tvlMultiplierMinimum < _settings.tvlMultiplierMaximum,
            errorsList.TVL_MULTIPLIER_IS_WRONG_Y
        );

        settings = _settings;
    }

    function adminCreatePool(
        address token, 
        uint amountTokensIn, 
        uint amountCerUsdToMint, 
        address transferTo
    )
        public
        payable
        onlyRole(ROLE_ADMIN) // TODO: enable on production
        tokenDoesNotExistInPool(token)
    {
        uint poolId = pools.length;

        _safeTransferFromHelper(token, msg.sender, amountTokensIn);
        ICerbyTokenMinterBurner(cerUsdToken).mintHumanAddress(address(this), amountCerUsdToMint);

        // finding out how many tokens router have sent to us
        amountTokensIn = _getTokenBalance(token);
        require(
            amountTokensIn > 0,
            errorsList.AMOUNT_OF_TOKENS_MUST_BE_LARGER_THAN_ONE_F
        );

        // create new pool record
        uint newSqrtKValue = sqrt(uint(amountTokensIn) * uint(amountCerUsdToMint));

        // filling with 1 usd per hour in trades to reduce gas later
        uint32[NUMBER_OF_TRADE_PERIODS] memory tradeVolumePerPeriodInCerUsd;
        for(uint i; i<NUMBER_OF_TRADE_PERIODS; i++) {
            tradeVolumePerPeriodInCerUsd[i] = 1;
        }

        Pool memory pool = Pool(
            token,
            tradeVolumePerPeriodInCerUsd,
            uint128(amountTokensIn),
            uint128(amountCerUsdToMint),
            uint128(newSqrtKValue)
        );
        pools.push(pool);
        tokenToPoolId[token] = poolId;   
        totalCerUsdBalance += amountCerUsdToMint;

        // minting 1000 lp tokens to prevent attack
        _mint(
            DEAD_ADDRESS,
            poolId,
            MINIMUM_LIQUIDITY,
            ""
        );

        // minting initial lp tokens
        uint lpAmount = sqrt(uint(amountTokensIn) * uint(amountCerUsdToMint)) - MINIMUM_LIQUIDITY;
        _mint(
            transferTo,
            poolId,
            lpAmount,
            ""
        );

        emit PairCreated(
            token,
            poolId
        );

        emit LiquidityAdded(
            token, 
            amountTokensIn, 
            amountCerUsdToMint, 
            lpAmount
        );
    }

    function addTokenLiquidity(
        address token, 
        uint amountTokensIn, 
        uint expireTimestamp,
        address transferTo
    )
        public
        payable
        tokenMustExistInPool(token)
        transactionIsNotExpired(expireTimestamp)
        // checkForBots(msg.sender) // TODO: enable on production
        returns (uint)
    {
        uint poolId = tokenToPoolId[token];

        _safeTransferFromHelper(token, msg.sender, amountTokensIn);

        // finding out how many tokens we've actually received
        uint newTokenBalance = _getTokenBalance(token);
        amountTokensIn = newTokenBalance - pools[poolId].balanceToken;
        require(
            amountTokensIn > 0,
            errorsList.AMOUNT_OF_TOKENS_MUST_BE_LARGER_THAN_ONE_F
        );

        // finding out if for some reason we've received cerUSD tokens as well
        uint newTotalCerUsdBalance = _getTokenBalance(cerUsdToken);
        uint amountCerUsdIn = newTotalCerUsdBalance - totalCerUsdBalance;

        {
            // calculating new sqrt(k) value before updating pool
            uint newSqrtKValue = 
                sqrt(uint(pools[poolId].balanceToken) * 
                        uint(pools[poolId].balanceCerUsd));
            
            // minting trade fees
            uint amountLpTokensToMintAsFee = 
                _getMintFeeLiquidityAmount(
                    pools[poolId].lastSqrtKValue, 
                    newSqrtKValue, 
                    _totalSupply[poolId]
                );

            if (amountLpTokensToMintAsFee > 0) {
                _mint(
                    settings.feeToBeneficiary, 
                    poolId, 
                    amountLpTokensToMintAsFee,
                    ""
                );
            }
        }

        // minting LP tokens
        uint lpAmount = (amountTokensIn * _totalSupply[poolId]) / pools[poolId].balanceToken;
        _mint(
            transferTo,
            poolId,
            lpAmount,
            ""
        );     

        { // scope to avoid stack to deep error
            // calculating amount of cerUSD to mint according to current price
            uint amountCerUsdToMint = 
                (amountTokensIn * uint(pools[poolId].balanceCerUsd)) / 
                    uint(pools[poolId].balanceToken);
            require(
                amountCerUsdToMint > 0,
                errorsList.AMOUNT_OF_CERUSD_MUST_BE_LARGER_THAN_ONE_U
            );

            // minting cerUSD according to current pool
            ICerbyTokenMinterBurner(cerUsdToken).mintHumanAddress(address(this), amountCerUsdToMint);

            // updating pool
            totalCerUsdBalance = totalCerUsdBalance + amountCerUsdIn + amountCerUsdToMint;
            pools[poolId].balanceToken = 
                pools[poolId].balanceToken + uint128(amountTokensIn);
            pools[poolId].balanceCerUsd = 
                pools[poolId].balanceCerUsd + uint128(amountCerUsdIn + amountCerUsdToMint);
            pools[poolId].lastSqrtKValue = 
                uint128(sqrt(uint(pools[poolId].balanceToken) * 
                    uint(pools[poolId].balanceCerUsd)));

            emit LiquidityAdded(
                token, 
                amountTokensIn, 
                amountCerUsdToMint, 
                lpAmount
            );
        }

        return lpAmount;
    }

    function removeTokenLiquidity(
        address token, 
        uint amountLpTokensBalanceToBurn, 
        uint expireTimestamp,
        address transferTo
    )
        public
        tokenMustExistInPool(token)
        transactionIsNotExpired(expireTimestamp)
        // checkForBots(msg.sender) // TODO: enable on production
        returns (uint)
    {
        return _removeTokenLiquidity(
            token,
            amountLpTokensBalanceToBurn,
            transferTo
        );
    }

    function _removeTokenLiquidity(
        address token, 
        uint amountLpTokensBalanceToBurn, 
        address transferTo
    )
        private
        returns (uint)
    {
        uint poolId = tokenToPoolId[token];
        
        // finding out if for some reason we've received tokens
        uint oldTokenBalance = _getTokenBalance(token);
        uint amountTokensIn = oldTokenBalance - pools[poolId].balanceToken;

        // finding out if for some reason we've received cerUSD tokens as well
        uint amountCerUsdIn = _getTokenBalance(cerUsdToken) - totalCerUsdBalance;

        // calculating amount of tokens to transfer
        uint totalLPSupply = _totalSupply[poolId];
        uint amountTokensOut = 
            (uint(pools[poolId].balanceToken) * amountLpTokensBalanceToBurn) / totalLPSupply;       

        // calculating amount of cerUSD to burn
        uint amountCerUsdToBurn = 
            (uint(pools[poolId].balanceCerUsd) * amountLpTokensBalanceToBurn) / totalLPSupply;

        { // scope to avoid stack too deep error            
            // storing sqrt(k) value before updating pool
            uint newSqrtKValue = 
                sqrt(uint(pools[poolId].balanceToken) * 
                    uint(pools[poolId].balanceCerUsd));

            // minting trade fees
            uint amountLpTokensToMintAsFee = 
                _getMintFeeLiquidityAmount(
                    pools[poolId].lastSqrtKValue, 
                    newSqrtKValue, 
                    totalLPSupply
                );
            if (amountLpTokensToMintAsFee > 0) {
                _mint(
                    settings.feeToBeneficiary, 
                    poolId, 
                    amountLpTokensToMintAsFee,
                    ""
                );
            }

            // updating pool        
            totalCerUsdBalance = totalCerUsdBalance + amountCerUsdIn - amountCerUsdToBurn;
            pools[poolId].balanceToken = 
                pools[poolId].balanceToken + uint128(amountTokensIn) - uint128(amountTokensOut);
            pools[poolId].balanceCerUsd = 
                pools[poolId].balanceCerUsd + uint128(amountCerUsdIn) - uint128(amountCerUsdToBurn);
            pools[poolId].lastSqrtKValue = 
                uint128(sqrt(uint(pools[poolId].balanceToken) * 
                    uint(pools[poolId].balanceCerUsd)));

            // burning LP tokens from sender (without approval)
            _burn(msg.sender, poolId, amountLpTokensBalanceToBurn);

            // burning cerUSD
            ICerbyTokenMinterBurner(cerUsdToken).burnHumanAddress(address(this), amountCerUsdToBurn);
        }
        

        // transfering tokens
        _safeTransferHelper(token, transferTo, amountTokensOut, true);
        uint newTokenBalance = _getTokenBalance(token);
        require(
            newTokenBalance + amountTokensOut == oldTokenBalance,
            errorsList.FEE_ON_TRANSFER_TOKENS_ARENT_SUPPORTED_E
        );

        emit LiquidityRemoved(
            token, 
            amountTokensOut, 
            amountCerUsdToBurn, 
            amountLpTokensBalanceToBurn
        );

        return amountTokensOut;
    }

    function _getMintFeeLiquidityAmount(uint lastSqrtKValue, uint newSqrtKValue, uint totalLPSupply)
        private
        view
        returns (uint amountLpTokensToMintAsFee)
    {
        if (
            newSqrtKValue > lastSqrtKValue && 
            lastSqrtKValue > 0 &&
            settings.mintFeeMultiplier > 0
        ) {
            amountLpTokensToMintAsFee = 
                (totalLPSupply * MINT_FEE_DENORM * (newSqrtKValue - lastSqrtKValue)) / 
                    (newSqrtKValue * settings.mintFeeMultiplier + lastSqrtKValue * MINT_FEE_DENORM);
        }

        //amountLpTokensToMintAsFee = 0; // TODO: remove on production
    }

    function swapExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint amountTokensIn,
        uint minAmountTokensOut,
        uint expireTimestamp,
        address transferTo
    )
        public
        payable
        transactionIsNotExpired(expireTimestamp)
        // checkForBots(msg.sender) // TODO: enable on production
        returns (uint, uint)
    {

        // amountTokensIn must be larger than 1 to avoid rounding errors
        require(
            amountTokensIn > 1,
            errorsList.AMOUNT_OF_TOKENS_MUST_BE_LARGER_THAN_ONE_F
        );
    
        address fromAddress = msg.sender;
        uint amountTokensOut;
        if (tokenIn != cerUsdToken && tokenOut == cerUsdToken) {

            // getting amountTokensOut
            amountTokensOut = getOutputExactTokensForCerUsd(tokenIn, amountTokensIn);

            // checking slippage
            require(
                amountTokensOut >= minAmountTokensOut,
                errorsList.OUTPUT_CERUSD_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_H
            );

            // actually transferring the tokens to the pool
            _safeTransferFromHelper(tokenIn, fromAddress, amountTokensIn);

            // swapping XXX ---> cerUSD
            _swap(
                tokenIn,
                0,
                amountTokensOut,
                transferTo
            );
        } else if (tokenIn == cerUsdToken && tokenOut != cerUsdToken) {

            // getting amountTokensOut
            amountTokensOut = getOutputExactCerUsdForTokens(tokenOut, amountTokensIn);

            // checking slippage
            require(
                amountTokensOut >= minAmountTokensOut,
                errorsList.OUTPUT_TOKENS_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_i
            );

            // actually transferring the tokens to the pool
            // for cerUsd don't need to use SafeERC20
            _safeTransferFromHelper(tokenIn, fromAddress, amountTokensIn);

            // swapping cerUSD ---> YYY
            _swap(
                tokenOut,
                amountTokensOut,
                0,
                transferTo
            );
        // TODO: uncomment below
        } else if (tokenIn != cerUsdToken && tokenIn != cerUsdToken /*&& tokenIn != tokenOut*/) {

            // getting amountTokensOut=
            uint amountCerUsdOut = getOutputExactTokensForCerUsd(tokenIn, amountTokensIn);

            amountTokensOut = getOutputExactCerUsdForTokens(tokenOut, amountCerUsdOut);

            // checking slippage
            require(
                amountTokensOut >= minAmountTokensOut,
                errorsList.OUTPUT_TOKENS_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_i
            );

            // actually transferring the tokens to the pool
            _safeTransferFromHelper(tokenIn, fromAddress, amountTokensIn);

            // swapping XXX ---> cerUSD
            _swap(
                tokenIn,
                0,
                amountCerUsdOut,
                address(this)
            );

            // swapping cerUSD ---> YYY
            _swap(
                tokenOut,
                amountTokensOut,
                0,
                transferTo
            );
        } else {
            revert(errorsList.SWAP_TOKEN_TO_SAME_TOKEN_IS_FORBIDDEN_L);
        }
        

        return (amountTokensIn, amountTokensOut);
    }

    
    function swapTokensForExactTokens(
        address tokenIn,
        address tokenOut,
        uint amountTokensOut,
        uint maxAmountTokensIn,
        uint expireTimestamp,
        address transferTo
    )
        public
        payable
        transactionIsNotExpired(expireTimestamp)
        // checkForBots(msg.sender) // TODO: enable on production
        returns (uint, uint)
    {
        address fromAddress = msg.sender;
        uint amountTokensIn;
        if (tokenIn != cerUsdToken && tokenOut == cerUsdToken) {

            // getting amountTokensOut
            amountTokensIn = getInputTokensForExactCerUsd(tokenIn, amountTokensOut);

            // checking slippage
            require(
                amountTokensIn <= maxAmountTokensIn,
                errorsList.INPUT_TOKENS_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_K
            );

            // amountTokensIn must be larger than 1 to avoid rounding errors
            require(
                amountTokensIn > 1,
                errorsList.AMOUNT_OF_TOKENS_MUST_BE_LARGER_THAN_ONE_F
            );

            // actually transferring the tokens to the pool
            _safeTransferFromHelper(tokenIn, fromAddress, amountTokensIn);

            // swapping XXX ---> cerUSD
            _swap(
                tokenIn,
                0,
                amountTokensOut,
                transferTo
            );
        } else if (tokenIn == cerUsdToken && tokenOut != cerUsdToken) {

            // getting amountTokensOut
            amountTokensIn = getInputCerUsdForExactTokens(tokenOut, amountTokensOut);

            // checking slippage
            require(
                amountTokensIn <= maxAmountTokensIn,
                errorsList.INPUT_CERUSD_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_J
            );

            // amountTokensIn must be larger than 1 to avoid rounding errors
            require(
                amountTokensIn > 1,
                errorsList.AMOUNT_OF_CERUSD_MUST_BE_LARGER_THAN_ONE_U
            );

            // actually transferring the tokens to the pool
            _safeTransferFromHelper(tokenIn, fromAddress, amountTokensIn);

            // swapping cerUSD ---> YYY
            _swap(
                tokenOut,
                amountTokensOut,
                0,
                transferTo
            );
        // TODO: uncomment below
        } else if (tokenIn != cerUsdToken && tokenOut != cerUsdToken /*&& tokenIn != tokenOut*/) {

            // getting amountTokensOut
            uint amountCerUsdOut = getInputCerUsdForExactTokens(tokenOut, amountTokensOut);
            require(
                amountCerUsdOut > 1,
                errorsList.AMOUNT_OF_CERUSD_MUST_BE_LARGER_THAN_ONE_U
            );

            amountTokensIn = getInputTokensForExactCerUsd(tokenIn, amountCerUsdOut);

            // checking slippage
            require(
                amountTokensIn <= maxAmountTokensIn,
                errorsList.INPUT_TOKENS_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_K
            );

            // amountTokensIn must be larger than 1 to avoid rounding errors
            require(
                amountTokensIn > 1,
                errorsList.AMOUNT_OF_TOKENS_MUST_BE_LARGER_THAN_ONE_F
            );

            // actually transferring the tokens to the pool
            _safeTransferFromHelper(tokenIn, fromAddress, amountTokensIn);
            
            // swapping XXX ---> cerUSD
            _swap(
                tokenIn,
                0,
                amountCerUsdOut,
                address(this)
            );

            // swapping cerUSD ---> YYY
            _swap(
                tokenOut,
                amountTokensOut,
                0,
                transferTo
            );
        } else {
            revert(errorsList.SWAP_TOKEN_TO_SAME_TOKEN_IS_FORBIDDEN_L);
        }
        return (amountTokensIn, amountTokensOut);
    }

    // low level swap
    function swap(
        address token,
        uint amountTokensOut,
        uint amountCerUsdOut,
        address transferTo
    )
        public
        payable
        // checkForBots(msg.sender)
    {
        _swap(
            token,
            amountTokensOut,
            amountCerUsdOut,
            transferTo
        );
    }
    function _swap(
        address token,
        uint amountTokensOut,
        uint amountCerUsdOut,
        address transferTo
    )
        private
        tokenMustExistInPool(token)
    {
        uint poolId = tokenToPoolId[token];

        // finding out how many amountCerUsdIn we received
        uint amountCerUsdIn = _getTokenBalance(cerUsdToken) - totalCerUsdBalance;

        // finding out how many amountTokensIn we received
        uint amountTokensIn = _getTokenBalance(token) - pools[poolId].balanceToken;
        require(
            amountTokensIn + amountCerUsdIn > 1,
            errorsList.AMOUNT_OF_CERUSD_OR_TOKENS_MUST_BE_LARGER_THAN_ONE_O
        );

        // calculating fees
        // if swap is ANY --> cerUSD, fee is calculated
        // if swap is cerUSD --> ANY, fee is zero
        uint fee = 
            amountCerUsdIn > 1 && amountTokensIn <= 1?
                FEE_DENORM:
                getCurrentOneMinusFeeBasedOnTrades(poolId);

        { // scope to avoid stack too deep error

            // calculating old K value including trade fees (multiplied by FEE_DENORM^2)
            uint beforeKValueDenormed = 
                uint(pools[poolId].balanceCerUsd) * FEE_DENORM *
                uint(pools[poolId].balanceToken) * FEE_DENORM;

            // calculating new pool values
            uint _totalCerUsdBalance = totalCerUsdBalance + amountCerUsdIn - amountCerUsdOut;
            uint _balanceCerUsd = 
                uint(pools[poolId].balanceCerUsd) + amountCerUsdIn - amountCerUsdOut;
            uint _balanceToken =
                uint(pools[poolId].balanceToken) + amountTokensIn - amountTokensOut;

            // calculating new K value including trade fees (multiplied by FEE_DENORM^2)
            uint afterKValueDenormed = 
                (_balanceCerUsd * FEE_DENORM - amountCerUsdIn * (FEE_DENORM - fee)) * 
                (_balanceToken * FEE_DENORM - amountTokensIn * (FEE_DENORM - fee));
            require(
                afterKValueDenormed >= beforeKValueDenormed,
                errorsList.INVARIANT_K_VALUE_MUST_BE_INCREASED_ON_ANY_TRADE_P
            );

            // updating pool values
            totalCerUsdBalance = _totalCerUsdBalance;
            pools[poolId].balanceCerUsd = uint128(_balanceCerUsd);
            pools[poolId].balanceToken = uint128(_balanceToken);
        }

        // updating 1 hour trade pool values
        uint currentPeriod = getCurrentPeriod();
        uint nextPeriod = (getCurrentPeriod() + 1) % NUMBER_OF_TRADE_PERIODS;
        unchecked {
            // wrapping any uint32 overflows
            // stores in USD value
            pools[poolId].tradeVolumePerPeriodInCerUsd[currentPeriod] += 
                uint32( (amountCerUsdIn + amountCerUsdOut) / TRADE_VOLUME_DENORM);
        }

        // clearing next 1 hour trade value
        if (pools[poolId].tradeVolumePerPeriodInCerUsd[nextPeriod] > 1)
        {
            // gas saving to not zero the field
            pools[poolId].tradeVolumePerPeriodInCerUsd[nextPeriod] = 1;
        }

        // transferring tokens from contract to user if any
        if (amountTokensOut > 0) {
            _safeTransferHelper(token, transferTo, amountTokensOut, true);

            // making sure exactly amountTokensOut tokens were sent out
            uint newTokenBalance = _getTokenBalance(token);
            require(
                newTokenBalance == pools[poolId].balanceToken,
                errorsList.FEE_ON_TRANSFER_TOKENS_ARENT_SUPPORTED_E
            );
        }

        // transferring cerUsd tokens to user if any
        if (amountCerUsdOut > 0) {
            _safeTransferHelper(cerUsdToken, transferTo, amountCerUsdOut, true);
        }     

        emit Swap(
            token,
            msg.sender, 
            amountTokensIn, 
            amountCerUsdIn, 
            amountTokensOut, 
            amountCerUsdOut,
            FEE_DENORM - fee, // (1 - fee) * FEE_DENORM
            transferTo
        );
    }

    function _getTokenBalance(address token)
        private
        view
        returns (uint balanceToken)
    {
        if (token == nativeToken) {
            balanceToken = address(this).balance;
        } else {
            balanceToken = IERC20(token).balanceOf(address(this));
        }

        return balanceToken;
    }

    function _safeTransferFromHelper(address token, address from, uint amount)
        private
    {
        if (token != nativeToken) {
            // caller must not send any native tokens
            require(
                msg.value == 0,
                errorsList.MSG_VALUE_PROVIDED_MUST_BE_ZERO_G
            );

            if (from != address(this)) {
                _safeTransferFrom(token, from, address(this), amount);
            }
        } else if (token == nativeToken)  {
            // caller must sent some native tokens
            require(
                msg.value >= amount,
                errorsList.MSG_VALUE_PROVIDED_MUST_BE_LARGER_THAN_AMOUNT_IN_T
            );

            // refunding extra native tokens
            // to make sure msg.value == amount
            if (msg.value > amount) {
                _safeTransferHelper(
                    nativeToken, 
                    msg.sender,
                    msg.value - amount,
                    false
                );
            }
        }
    }

    function _safeTransferHelper(address token, address to, uint amount, bool needToCheck)
        private
    {
        // some transfer such as refund excess of msg.value
        // we don't check for bots
        if (needToCheck) {
            //checkTransactionForBots(token, msg.sender, to); // TODO: enable on production
        }

        if (to != address(this)) {
            if (token == nativeToken) {
                _safeTransferNative(to, amount);
            } else {
                _safeTransferToken(token, to, amount);
            }

        }
    }
    
    function _safeTransferToken(
        address token,
        address to,
        uint value
    ) private {
        // 0xa9059cbb = bytes4(keccak256(bytes('transfer(address,uint)')));
        (bool success, bytes memory data) = 
            token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            errorsList.SAFE_TRANSFER_FAILED_R
        );
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint value
    ) private {
        // 0x23b872dd = bytes4(keccak256(bytes('transferFrom(address,address,uint)')));
        (bool success, bytes memory data) = 
            token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            errorsList.SAFE_TRANSFER_FROM_FAILED_S
        );
    }

    function _safeTransferNative(address to, uint value) private {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, errorsList.SAFE_TRANSFER_NATIVE_FAILED_Q);
    }

    function syncTokenBalanceInPool(address token)
        public
        tokenMustExistInPool(token)
        // checkForBotsAndExecuteCronJobs(msg.sender) // TODO: enable on production
    {
        uint poolId = tokenToPoolId[token];
        pools[poolId].balanceToken = uint128(_getTokenBalance(token));
        
        uint newTotalCerUsdBalance = _getTokenBalance(cerUsdToken);
        pools[poolId].balanceCerUsd = 
            newTotalCerUsdBalance > totalCerUsdBalance?
                pools[poolId].balanceCerUsd + uint128(newTotalCerUsdBalance - totalCerUsdBalance):
                pools[poolId].balanceCerUsd - uint128(totalCerUsdBalance - newTotalCerUsdBalance);

        totalCerUsdBalance = newTotalCerUsdBalance;

        emit Sync(token, pools[poolId].balanceToken, pools[poolId].balanceCerUsd);
    }

    function skimPool(address token)
        public
        tokenMustExistInPool(token)
        // checkForBotsAndExecuteCronJobs(msg.sender) // TODO: enable on production
    {
        uint poolId = tokenToPoolId[token];
        uint newBalanceToken = _getTokenBalance(token);
        uint newBalanceCerUsd = _getTokenBalance(cerUsdToken);

        uint diffBalanceToken = newBalanceToken - pools[poolId].balanceToken;
        if (diffBalanceToken > 0) {
            _safeTransferHelper(token, msg.sender, diffBalanceToken, false);
        }

        uint diffBalanceCerUsd = newBalanceCerUsd - pools[poolId].balanceCerUsd;
        if (diffBalanceCerUsd > 0) {
            _safeTransferHelper(cerUsdToken, msg.sender, diffBalanceCerUsd, false);
        }
    }

    function getCurrentPeriod()
        private
        view
        returns (uint)
    {
        return (block.timestamp / ONE_PERIOD_IN_SECONDS) % NUMBER_OF_TRADE_PERIODS;
    }

    function getCurrentOneMinusFeeBasedOnTrades(address token)
        public
        view
        returns (uint fee)
    {
        return getCurrentOneMinusFeeBasedOnTrades(tokenToPoolId[token]);
    }

    function getCurrentOneMinusFeeBasedOnTrades(uint poolId)
        private
        view
        returns (uint fee)
    {
        // getting last 24 hours trade volume in USD
        uint currentPeriod = getCurrentPeriod();
        uint nextPeriod = (currentPeriod + 1) % NUMBER_OF_TRADE_PERIODS;
        uint volume;
        for(uint i; i<NUMBER_OF_TRADE_PERIODS; i++)
        {
            // skipping current and next period because those values are currently updating
            // and are incorrect
            if (i == currentPeriod || i == nextPeriod) continue;

            volume += pools[poolId].tradeVolumePerPeriodInCerUsd[i];
        }

        // multiplying it to make wei dimention
        volume = volume * TRADE_VOLUME_DENORM;

        // trades <= TVL * min              ---> fee = feeMaximum
        // TVL * min < trades < TVL * max   ---> fee is between feeMaximum and feeMinimum
        // trades >= TVL * max              ---> fee = feeMinimum
        uint tvlMin = 
            (pools[poolId].balanceCerUsd * settings.tvlMultiplierMinimum) / TVL_MULTIPLIER_DENORM;
        uint tvlMax = 
            (pools[poolId].balanceCerUsd * settings.tvlMultiplierMaximum) / TVL_MULTIPLIER_DENORM;
        if (volume <= tvlMin) {
            fee = settings.feeMaximum; // 1.00%
        } else if (tvlMin < volume && volume < tvlMax) {
            fee = 
                settings.feeMaximum - 
                    ((volume - tvlMin) * (settings.feeMaximum - settings.feeMinimum))  / 
                        (tvlMax - tvlMin); // between 1.00% and 0.01%
        } else if (volume > tvlMax) {
            fee = settings.feeMinimum; // 0.01%
        }

        // returning 1 - fee for further calculations
        return FEE_DENORM - fee;
    }

    function getOutputExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint amountTokensIn
    )
        public
        view
        returns (uint amountTokensOut)
    {
        if (tokenIn != cerUsdToken && tokenOut == cerUsdToken) {

            // getting amountTokensOut
            amountTokensOut = getOutputExactTokensForCerUsd(tokenIn, amountTokensIn);
        } else if (tokenIn == cerUsdToken && tokenOut != cerUsdToken) {

            // getting amountTokensOut
            amountTokensOut = getOutputExactCerUsdForTokens(tokenOut, amountTokensIn);
        } else if (tokenIn != cerUsdToken && tokenIn != cerUsdToken) {

            // getting amountTokensOut
            uint amountCerUsdOut = getOutputExactTokensForCerUsd(tokenIn, amountTokensIn);

            amountTokensOut = getOutputExactCerUsdForTokens(tokenOut, amountCerUsdOut);
        }
        return amountTokensOut;
    }

    function getInputTokensForExactTokens(
        address tokenIn,
        address tokenOut,
        uint amountTokensOut
    )
        public
        view
        returns (uint amountTokensIn)
    {
        if (tokenIn != cerUsdToken && tokenOut == cerUsdToken) {

            // getting amountTokensOut
            amountTokensIn = getInputTokensForExactCerUsd(tokenIn, amountTokensOut);
        } else if (tokenIn == cerUsdToken && tokenOut != cerUsdToken) {

            // getting amountTokensOut
            amountTokensIn = getInputCerUsdForExactTokens(tokenOut, amountTokensOut);
        } else if (tokenIn != cerUsdToken && tokenOut != cerUsdToken) {

            // getting amountTokensOut
            uint amountCerUsdOut = getInputCerUsdForExactTokens(tokenOut, amountTokensOut);

            amountTokensIn = getInputTokensForExactCerUsd(tokenIn, amountCerUsdOut);
        }
        return amountTokensIn;
    }

    function getOutputExactTokensForCerUsd(address token, uint amountTokensIn)
        private
        view
        tokenMustExistInPool(token)
        returns (uint)
    {
        uint poolId = tokenToPoolId[token];
        return _getOutput(
            amountTokensIn,
            uint(pools[poolId].balanceToken),
            uint(pools[poolId].balanceCerUsd),
            getCurrentOneMinusFeeBasedOnTrades(poolId)
        );
    }

    function getOutputExactCerUsdForTokens(address token, uint amountCerUsdIn)
        private
        view
        tokenMustExistInPool(token)
        returns (uint)
    {
        uint poolId = tokenToPoolId[token];
        return _getOutput(
            amountCerUsdIn,
            uint(pools[poolId].balanceCerUsd),
            uint(pools[poolId].balanceToken),
            //getCurrentOneMinusFeeBasedOnTrades(poolId)
            FEE_DENORM // fee is zero for swaps cerUsd --> Any
        );
    }

    function _getOutput(uint amountIn, uint reservesIn, uint reservesOut, uint poolFee)
        private
        view
        returns (uint)
    {
        require(
            reservesIn > 1000 && reservesOut > 1000,
            errorsList.RESERVES_IN_AND_OUT_MUST_BE_LARGER_THAN_1000_V
        );

        uint amountInWithFee = amountIn * poolFee;
        uint amountOut = 
            (reservesOut * amountInWithFee) / (reservesIn * FEE_DENORM + amountInWithFee);
        return amountOut;
    }

    function getInputTokensForExactCerUsd(address token, uint amountCerUsdOut)
        private
        view
        tokenMustExistInPool(token)
        returns (uint)
    {
        uint poolId = tokenToPoolId[token];
        return _getInput(
            amountCerUsdOut,
            uint(pools[poolId].balanceToken),
            uint(pools[poolId].balanceCerUsd),
            getCurrentOneMinusFeeBasedOnTrades(poolId)
        );
    }

    function getInputCerUsdForExactTokens(address token, uint amountTokensOut)
        private
        view
        tokenMustExistInPool(token)
        returns (uint)
    {
        uint poolId = tokenToPoolId[token];
        return _getInput(
            amountTokensOut,
            uint(pools[poolId].balanceCerUsd),
            uint(pools[poolId].balanceToken),
            //getCurrentOneMinusFeeBasedOnTrades(poolId)
            FEE_DENORM // fee is zero for swaps cerUsd --> Any
        );
    }

    function _getInput(uint amountOut, uint reservesIn, uint reservesOut, uint poolFee)
        private
        view
        returns (uint)
    {
        require(
            reservesIn > 1000 && reservesOut > 1000,
            errorsList.RESERVES_IN_AND_OUT_MUST_BE_LARGER_THAN_1000_V
        );

        uint amountIn = (reservesIn * amountOut * FEE_DENORM) /
            (poolFee * (reservesOut - amountOut)) + 1; // adding +1 for any rounding trims
        return amountIn;
    }

    function getPoolsByIds(uint[] calldata ids)
        public
        view
        returns (Pool[] memory)
    {
        Pool[] memory outputPools = new Pool[](ids.length);
        for(uint i; i<ids.length; i++) {
            outputPools[i] = pools[ids[i]];
        }
        return outputPools;
    }

    function getPoolsByTokens(address[] calldata tokens)
        public
        view
        returns (Pool[] memory)
    {
        Pool[] memory outputPools = new Pool[](tokens.length);
        for(uint i; i<tokens.length; i++) {
            outputPools[i] = pools[tokenToPoolId[tokens[i]]];
        }
        return outputPools;
    }

    function sqrt(uint y) 
        private 
        pure 
        returns (uint z) 
    {
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