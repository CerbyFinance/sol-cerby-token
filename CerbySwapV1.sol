// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.11;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/ICerbyTokenMinterBurner.sol";
import "./interfaces/ICerbySwapLP1155V1.sol";
import "./interfaces/IERC20.sol";
import "./CerbyCronJobsExecution.sol";
import "./CerbySwapLP1155V1.sol";


contract CerbySwapV1 is CerbySwapLP1155V1 {

    string constant ALREADY_INITIALIZED_A = "A";
    string constant TOKEN_ALREAD_EXISTS_B = "B";
    string constant TOKEN_DOES_NOT_EXIST_C = "C";
    string constant TRANSACTION_IS_EXPIRED_D = "D";
    string constant FEE_ON_TRANSFER_TOKENS_ARENT_SUPPORTED_E = "E";
    string constant AMOUNT_OF_TOKENS_IN_MUST_BE_LARGER_THAN_ZERO_F = "F";
    string constant SAFE_TRANSFER_FROM_FAILED_G = "G";
    string constant OUTPUT_CERUSD_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_H = "H";
    string constant OUTPUT_TOKENS_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_i = "i";
    string constant OUTPUT_CERUSD_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_J = "J";
    string constant OUTPUT_TOKENS_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_K = "K";
    string constant SWAP_CERUSD_FOR_CERUSD_IS_FORBIDDEN_L = "L";
    string constant ONE_OF_TOKENIN_OR_TOKEN_OUT_IS_WRONG_M = "M";
    string constant POOL_POS_DOES_NOT_EXIST_N = "N";
    string constant AMOUNT_OF_CERUSD_OR_TOKENS_MUST_BE_LARGER_THAN_ZERO_O = "O";
    string constant INVARIANT_K_VALUE_MUST_BE_INCREASED_ON_ANY_TRADE_P = "P";
    string constant SAFE_TRANSFER_ETH_FAILED_Q = "Q";
    string constant SAFE_TRANSFER_FAILED_R = "R";

    Pool[] pools;
    mapping(address => uint) tokenToPoolPosition;
    uint totalCerUsdBalance;

    /* KOVAN 
    // "0x37E140032ac3a8428ed43761a9881d4741Eb3a73", "997503992263724670916", 0, "2041564156"
    // "0x14769F96e57B80c66837701DE0B43686Fb4632De", "1000000000000000000000", 0, "2041564156"
    // "0x37E140032ac3a8428ed43761a9881d4741Eb3a73","0x14769F96e57B80c66837701DE0B43686Fb4632De","10000000000000000000000","0","2041564156"
    // "0x14769F96e57B80c66837701DE0B43686Fb4632De","0x37E140032ac3a8428ed43761a9881d4741Eb3a73","1000000000000000000000","0","2041564156"
    
    address constant testCerbyToken = 0x3d982cB3BC8D1248B17f22b567524bF7BFFD3b11;
    address constant cerUsdToken = 0x37E140032ac3a8428ed43761a9881d4741Eb3a73;
    address constant testUsdcToken = 0x14769F96e57B80c66837701DE0B43686Fb4632De;*/

    /* Localhost
    // "0xde402E9D305bAd483d47bc858cC373c5a040A62D", "997503992263724670916", 0, "2041564156"
    // "0xCd300dd54345F48Ba108Df3D792B6c2Dbb17edD2", "1000000000000000000000", 0, "2041564156"
    // "0xF3B07F8167b665BA3E2DD29c661DeE3a1da2380a","0x2c4fE51d1Ad5B88cD2cc2F45ad1c0C857f06225e","1000000000000000000000","0","20415641000","0x539FaA851D86781009EC30dF437D794bCd090c8F"
    // "0x2c4fE51d1Ad5B88cD2cc2F45ad1c0C857f06225e","0xF3B07F8167b665BA3E2DD29c661DeE3a1da2380a","1000000000000000000000","0","20415641000","0x539FaA851D86781009EC30dF437D794bCd090c8F"
    1000000000000000000011 494510434669677019755 489223177884861877370
    2047670051318999350473 1000000000000000000011
    */
    address testCerbyToken = 0x2c4fE51d1Ad5B88cD2cc2F45ad1c0C857f06225e; // TODO: remove on production
    address cerUsdToken = 0xF3B07F8167b665BA3E2DD29c661DeE3a1da2380a; // TODO: make constant
    address testUsdcToken = 0x2a5E269bF364E347942c464a999D8c8ac2E6CE94; // TODO: remove on production

    address nativeToken;

    uint constant FEE_DENORM = 10000;

    uint constant NUMBER_OF_4HOUR_INTERVALS = 8;
    uint constant MINIMUM_LIQUIDITY = 1000;
    address constant DEAD_ADDRESS = address(0xdead);
    address public feeToBeneficiary = DEAD_ADDRESS;


    struct Pool {
        address token;
        uint32[NUMBER_OF_4HOUR_INTERVALS] hourlyTradeVolumeInCerUsd;
        uint112 balanceToken;
        uint112 balanceCerUsd;
        uint112 lastSqrtKValue;
    }

    constructor() {
        _setupRole(ROLE_ADMIN, msg.sender);

        feeToBeneficiary = msg.sender;

        // Filling with empty pool 0th position
        uint32[NUMBER_OF_4HOUR_INTERVALS] memory hourlyTradeVolumeInCerUsd;
        pools.push(Pool(
            address(0),
            hourlyTradeVolumeInCerUsd,
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
            tokenToPoolPosition[token] > 0 && token != cerUsdToken,
            TOKEN_DOES_NOT_EXIST_C
        );
        _;
    }

    modifier oneOfTokensMustExistInPool(address tokenIn, address tokenOut)
    {
        require(
            tokenToPoolPosition[tokenIn] > 0 && (
                tokenOut == cerUsdToken ||
                tokenToPoolPosition[tokenOut] > 0
            ) ||
            tokenToPoolPosition[tokenOut] > 0 && (
                tokenIn == cerUsdToken ||
                tokenToPoolPosition[tokenIn] > 0
            ),
            ONE_OF_TOKENIN_OR_TOKEN_OUT_IS_WRONG_M
        );
        _;
    }

    modifier tokenDoesNotExistInPool(address token)
    {
        require(
            tokenToPoolPosition[token] == 0 && token != cerUsdToken,
            TOKEN_ALREAD_EXISTS_B
        );
        _;
    }

    modifier transactionIsNotExpired(uint expireTimestamp)
    {
        require(
            block.timestamp <= expireTimestamp,
            TRANSACTION_IS_EXPIRED_D
        );
        _;
    }

    function getTokenToPoolPosition(address token) 
        public
        view
        returns (uint)
    {
        return tokenToPoolPosition[token];
    }

    // TODO: remove on production
    function testSetupTokens(address , address _testCerbyToken, address _cerUsdToken, address _testUsdcToken, address _nativeToken)
        public
    {
        //lpErc1155V1 = _lpErc1155V1;
        testCerbyToken= _testCerbyToken;
        cerUsdToken = _cerUsdToken;
        testUsdcToken = _testUsdcToken;
        nativeToken = _nativeToken;
    }

    // TODO: remove on production
    function adminInitialize() 
        public
        // onlyRole(ROLE_ADMIN) // TODO: enable on production
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
    

    function adminUpdateFeeToBeneficiary(address newFeeToBeneficiary)
        public
        // onlyRole(ROLE_ADMIN) // TODO: enable on production
    {
        feeToBeneficiary = newFeeToBeneficiary;
    }

    function adminCreatePool(
        address token, 
        uint amountTokensIn, 
        uint amountCerUsdIn, 
        address transferTo
    )
        public
        // onlyRole(ROLE_ADMIN) // TODO: enable on production
        tokenDoesNotExistInPool(token)
    {
        uint poolPos = pools.length;

        _safeTransferFromHelper(token, msg.sender, amountTokensIn);
        ICerbyTokenMinterBurner(cerUsdToken).mintHumanAddress(address(this), amountCerUsdIn);

        // finding out how many tokens router have sent to us
        amountTokensIn = _getTokenBalance(token);
        require(
            amountTokensIn > 0,
            AMOUNT_OF_TOKENS_IN_MUST_BE_LARGER_THAN_ZERO_F
        );

        // create new pool record
        uint newSqrtKValue = sqrt(uint(amountTokensIn) * uint(amountCerUsdIn));
        uint32[NUMBER_OF_4HOUR_INTERVALS] memory hourlyTradeVolumeInCerUsd;
        Pool memory pool = Pool(
            token,
            hourlyTradeVolumeInCerUsd,
            uint112(amountTokensIn),
            uint112(amountCerUsdIn),
            uint112(newSqrtKValue)
        );
        pools.push(pool);
        tokenToPoolPosition[token] = poolPos;   
        totalCerUsdBalance += amountCerUsdIn;

        // minting 1000 lp tokens to prevent attack
        _mint(
            DEAD_ADDRESS,
            poolPos,
            MINIMUM_LIQUIDITY,
            ""
        );

        // minting initial lp tokens
        uint lpAmount = sqrt(uint(amountTokensIn) * uint(amountCerUsdIn)) - MINIMUM_LIQUIDITY;
        _mint(
            transferTo,
            poolPos,
            lpAmount,
            ""
        );
    }

    function addTokenLiquidity(address fromAddress, address token, uint amountTokensIn, address transferTo)
        public
        payable
        tokenMustExistInPool(token)
        // checkForBotsAndExecuteCronJobs(msg.sender) // TODO: enable on production
    {
        uint poolPos = tokenToPoolPosition[token];

        _safeTransferFromHelper(token, fromAddress, amountTokensIn);

        // finding out how many tokens we've actually received
        uint newTokenBalance = _getTokenBalance(token);
        amountTokensIn = newTokenBalance - pools[poolPos].balanceToken;
        require(
            amountTokensIn > 0,
            AMOUNT_OF_TOKENS_IN_MUST_BE_LARGER_THAN_ZERO_F
        );

        // finding out if for some reason we've received cerUSD tokens as well
        uint newTotalCerUsdBalance = _getTokenBalance(cerUsdToken);
        uint amountCerUsdIn = newTotalCerUsdBalance - totalCerUsdBalance;

        // calculating amount of cerUSD to mint
        uint mintCerUsdAmount = 
            (amountTokensIn * uint(pools[poolPos].balanceCerUsd)) / uint(pools[poolPos].balanceToken) - 
                amountCerUsdIn;

        // storing sqrt(k) value before updating pool
        uint112 lastSqrtKValue = pools[poolPos].lastSqrtKValue;
        uint112 newSqrtKValue = uint112(sqrt(uint(pools[poolPos].balanceToken) * uint(pools[poolPos].balanceCerUsd)));

        // updating pool
        totalCerUsdBalance = newTotalCerUsdBalance;
        pools[poolPos].lastSqrtKValue = newSqrtKValue;
        pools[poolPos].balanceToken = uint112(newTokenBalance);
        pools[poolPos].balanceCerUsd = 
            pools[poolPos].balanceCerUsd + uint112(amountCerUsdIn + mintCerUsdAmount);

        // minting cerUSD according to current pool
        ICerbyTokenMinterBurner(cerUsdToken).mintHumanAddress(address(this), mintCerUsdAmount);

        // minting LP tokens
        uint totalLPSupply = _totalSupply[poolPos];
        uint lpAmount = (amountTokensIn * totalLPSupply) / pools[poolPos].balanceToken;
        _mint(
            transferTo,
            poolPos,
            lpAmount,
            ""
        );

        // minting trade fees
        uint amountLpTokensToMintAsFee = _getMintFeeLiquidityAmount(lastSqrtKValue, newSqrtKValue, totalLPSupply);
        if (amountLpTokensToMintAsFee > 0) {
            _mint(
                feeToBeneficiary, 
                poolPos, 
                amountLpTokensToMintAsFee,
                ""
            );
        }
    }

    function removeTokenLiquidity(address fromAddress, address token, uint amountLpTokensBalanceToBurn, address transferTo)
        public
        payable
        tokenMustExistInPool(token)
        // checkForBotsAndExecuteCronJobs(msg.sender) // TODO: enable on production
        returns (uint)
    {
        uint poolPos = tokenToPoolPosition[token];

        if (fromAddress != address(this)) {
            safeTransferFrom(
                fromAddress, 
                address(this), 
                poolPos, 
                amountLpTokensBalanceToBurn, 
                ""
            );
        }

        // finding out if for some reason we've received tokens
        uint oldTokenBalance = _getTokenBalance(token);
        uint amountTokensIn = oldTokenBalance - pools[poolPos].balanceToken;

        // finding out if for some reason we've received cerUSD tokens as well
        uint amountCerUsdIn = _getTokenBalance(cerUsdToken) - totalCerUsdBalance;

        // calculating amount of tokens to transfer
        uint totalLPSupply = _totalSupply[poolPos];
        uint amountTokensOut = 
            (uint(pools[poolPos].balanceToken) * amountLpTokensBalanceToBurn) / totalLPSupply;       

        // calculating amount of cerUSD to burn
        uint amountCerUsdToBurn = 
            (uint(pools[poolPos].balanceCerUsd) * amountLpTokensBalanceToBurn) / totalLPSupply;

        { // scope to avoid stack too deep error            
            // storing sqrt(k) value before updating pool
            uint112 lastSqrtKValue = pools[poolPos].lastSqrtKValue;
            uint112 newSqrtKValue = uint112(sqrt(uint(pools[poolPos].balanceToken) * uint(pools[poolPos].balanceCerUsd)));

            // updating pool        
            totalCerUsdBalance = totalCerUsdBalance + amountCerUsdIn - amountCerUsdToBurn;
            pools[poolPos].lastSqrtKValue = newSqrtKValue;
            pools[poolPos].balanceToken = 
                pools[poolPos].balanceToken + uint112(amountTokensIn) - uint112(amountTokensOut);
            pools[poolPos].balanceCerUsd = 
                pools[poolPos].balanceCerUsd + uint112(amountCerUsdIn) - uint112(amountCerUsdToBurn);

            // burning LP tokens received by this contract
            burn(poolPos, amountLpTokensBalanceToBurn);

            // burning cerUSD
            ICerbyTokenMinterBurner(cerUsdToken).burnHumanAddress(address(this), amountCerUsdToBurn);

        
            // minting trade fees
            uint amountLpTokensToMintAsFee = 
                _getMintFeeLiquidityAmount(lastSqrtKValue, newSqrtKValue, totalLPSupply);
            if (amountLpTokensToMintAsFee > 0) {
                _mint(
                    feeToBeneficiary, 
                    poolPos, 
                    amountLpTokensToMintAsFee,
                    ""
                );
            }
        }

        // transfering tokens
        _safeTransferHelper(token, transferTo, amountTokensOut);
        uint newTokenBalance = _getTokenBalance(token);
        require(
            newTokenBalance + amountTokensOut == oldTokenBalance,
            FEE_ON_TRANSFER_TOKENS_ARENT_SUPPORTED_E
        );

        return amountTokensOut;
    }

    function _getMintFeeLiquidityAmount(uint lastSqrtKValue, uint newSqrtKValue, uint totalLPSupply)
        private
        pure
        returns (uint amountLpTokensToMintAsFee)
    {
        if (
            newSqrtKValue > lastSqrtKValue && 
            lastSqrtKValue > 0
        ) {
            amountLpTokensToMintAsFee = (totalLPSupply * (newSqrtKValue - lastSqrtKValue)) / (newSqrtKValue * 5 + lastSqrtKValue);
        }
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
        // checkForBotsAndExecuteCronJobs(msg.sender) // TODO: enable on production
        transactionIsNotExpired(expireTimestamp)
        returns (uint, uint)
    {
        require(
            amountTokensIn > 0,
            AMOUNT_OF_CERUSD_OR_TOKENS_MUST_BE_LARGER_THAN_ZERO_O
        );
    
        address fromAddress = msg.sender;
        uint amountTokensOut;
        if (tokenIn != cerUsdToken && tokenOut == cerUsdToken) {

            // getting amountTokensOut
            amountTokensOut = getOutputExactTokensForCerUsd(tokenIn, amountTokensIn);
            require(
                amountTokensOut >= minAmountTokensOut,
                OUTPUT_CERUSD_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_H
            );

            // actually transferring the tokens to the pool
            _safeTransferFromHelper(tokenIn, fromAddress, amountTokensIn);

            // swapping XXX ---> cerUSD
            swap(
                tokenIn,
                0,
                amountTokensOut,
                transferTo
            );
        } else if (tokenIn == cerUsdToken && tokenOut != cerUsdToken) {

            // getting amountTokensOut
            amountTokensOut = getOutputExactCerUsdForTokens(tokenOut, amountTokensIn);
            require(
                amountTokensOut >= minAmountTokensOut,
                OUTPUT_TOKENS_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_i
            );

            // actually transferring the tokens to the pool
            // for cerUsd don't need to use SafeERC20
            _safeTransferFromHelper(tokenIn, fromAddress, amountTokensIn);

            // swapping cerUSD ---> YYY
            swap(
                tokenOut,
                amountTokensOut,
                0,
                transferTo
            );
        } else if (tokenIn != cerUsdToken && tokenIn != cerUsdToken /*&& tokenIn != tokenOut*/) {

            // getting amountTokensOut=
            uint amountCerUsdOut = getOutputExactTokensForCerUsd(tokenIn, amountTokensIn);

            amountTokensOut = getOutputExactCerUsdForTokens(tokenOut, amountCerUsdOut);
            require(
                amountTokensOut >= minAmountTokensOut,
                OUTPUT_TOKENS_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_i
            );

            // actually transferring the tokens to the pool
            _safeTransferFromHelper(tokenIn, fromAddress, amountTokensIn);

            // swapping XXX ---> cerUSD
            swap(
                tokenIn,
                0,
                amountCerUsdOut,
                address(this)
            );

            // swapping cerUSD ---> YYY
            swap(
                tokenOut,
                amountTokensOut,
                0,
                transferTo
            );
        } else {
            revert(SWAP_CERUSD_FOR_CERUSD_IS_FORBIDDEN_L);
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
        // checkForBotsAndExecuteCronJobs(msg.sender) // TODO: enable on production
        returns (uint, uint)
    {
        address fromAddress = msg.sender;
        uint amountTokensIn;
        if (tokenIn != cerUsdToken && tokenOut == cerUsdToken) {

            // getting amountTokensOut
            amountTokensIn = getInputTokensForExactCerUsd(tokenIn, amountTokensOut);
            require(
                amountTokensIn <= maxAmountTokensIn,
                OUTPUT_TOKENS_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_K
            );
            require(
                amountTokensIn > 1,
                AMOUNT_OF_CERUSD_OR_TOKENS_MUST_BE_LARGER_THAN_ZERO_O
            );

            // actually transferring the tokens to the pool
            _safeTransferFromHelper(tokenIn, fromAddress, amountTokensIn);

            // swapping XXX ---> cerUSD
            swap(
                tokenIn,
                0,
                amountTokensOut,
                transferTo
            );
        } else if (tokenIn == cerUsdToken && tokenOut != cerUsdToken) {

            // getting amountTokensOut
            amountTokensIn = getInputCerUsdForExactTokens(tokenOut, amountTokensOut);
            require(
                amountTokensIn <= maxAmountTokensIn,
                OUTPUT_CERUSD_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_J
            );
            require(
                amountTokensIn > 1,
                AMOUNT_OF_CERUSD_OR_TOKENS_MUST_BE_LARGER_THAN_ZERO_O
            );

            // actually transferring the tokens to the pool
            _safeTransferFromHelper(tokenIn, fromAddress, amountTokensIn);

            // swapping cerUSD ---> YYY
            swap(
                tokenOut,
                amountTokensOut,
                0,
                transferTo
            );
        } else if (tokenIn != cerUsdToken && tokenOut != cerUsdToken /*&& tokenIn != tokenOut*/) {

            // getting amountTokensOut
            uint amountCerUsdOut = getInputCerUsdForExactTokens(tokenOut, amountTokensOut);
            require(
                amountCerUsdOut > 1,
                AMOUNT_OF_CERUSD_OR_TOKENS_MUST_BE_LARGER_THAN_ZERO_O
            );

            amountTokensIn = getInputTokensForExactCerUsd(tokenIn, amountCerUsdOut);
            require(
                amountTokensIn <= maxAmountTokensIn,
                OUTPUT_TOKENS_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_K
            );
            require(
                amountTokensIn > 1,
                AMOUNT_OF_CERUSD_OR_TOKENS_MUST_BE_LARGER_THAN_ZERO_O
            );

            // actually transferring the tokens to the pool
            _safeTransferFromHelper(tokenIn, fromAddress, amountTokensIn);

            // swapping XXX ---> cerUSD
            swap(
                tokenIn,
                0,
                amountCerUsdOut,
                address(this)
            );

            // swapping cerUSD ---> YYY
            swap(
                tokenOut,
                amountTokensOut,
                0,
                transferTo
            );
        } else {
            revert(SWAP_CERUSD_FOR_CERUSD_IS_FORBIDDEN_L);
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
        tokenMustExistInPool(token)
    {
        uint poolPos = tokenToPoolPosition[token];

        // finding out how many amountCerUsdIn we received
        uint newTotalCerUsdBalance = _getTokenBalance(cerUsdToken);
        uint amountCerUsdIn = newTotalCerUsdBalance - totalCerUsdBalance;

        // finding out how many amountTokensIn we received
        uint oldTokenBalance = _getTokenBalance(token);
        uint amountTokensIn = oldTokenBalance - pools[poolPos].balanceToken;
        require(
            amountTokensIn + amountCerUsdIn > 0,
            AMOUNT_OF_CERUSD_OR_TOKENS_MUST_BE_LARGER_THAN_ZERO_O
        );

        { // scope to avoid stack too deep error
            // calculating old K value including trade fees (multiplied by FEE_DENORM^2)
            uint fee = getCurrentFeeBasedOnTrades(poolPos);
            uint beforeKValueDenormed = 
                uint(pools[poolPos].balanceCerUsd) * FEE_DENORM *
                uint(pools[poolPos].balanceToken) * FEE_DENORM;

            // calculating new pool values
            uint _totalCerUsdBalance = totalCerUsdBalance + amountCerUsdIn - amountCerUsdOut;
            uint _balanceCerUsd = 
                uint(pools[poolPos].balanceCerUsd) + amountCerUsdIn - amountCerUsdOut;
            uint _balanceToken =
                uint(pools[poolPos].balanceToken) + amountTokensIn - amountTokensOut;

            // calculating new K value including trade fees (multiplied by FEE_DENORM^2)
            uint afterKValueDenormed = 
                (_balanceCerUsd * FEE_DENORM - amountCerUsdIn * (FEE_DENORM - fee)) * 
                (_balanceToken * FEE_DENORM - amountTokensIn * (FEE_DENORM - fee));
            require(
                afterKValueDenormed >= beforeKValueDenormed,
                INVARIANT_K_VALUE_MUST_BE_INCREASED_ON_ANY_TRADE_P
            );

            // updating pool values
            totalCerUsdBalance = _totalCerUsdBalance;
            pools[poolPos].balanceCerUsd = uint112(_balanceCerUsd);
            pools[poolPos].balanceToken = uint112(_balanceToken);
        }

        // updating 4hour trade pool values
        uint current4Hour = getCurrent4Hour();
        uint next4Hour = (getCurrent4Hour() + 1) % NUMBER_OF_4HOUR_INTERVALS;
        unchecked {
            // wrapping any uint32 overflows
            // stores in USD value
            pools[poolPos].hourlyTradeVolumeInCerUsd[current4Hour] += 
                uint32( (amountCerUsdIn + amountCerUsdOut) / 1e18);
        }

        // clearing next 4hour trade value
        if (pools[poolPos].hourlyTradeVolumeInCerUsd[next4Hour] > 0)
        {
            pools[poolPos].hourlyTradeVolumeInCerUsd[next4Hour] = 0;
        }

        // transferring tokens from contract to user
        if (amountTokensOut > 0) {
            _safeTransferHelper(token, transferTo, amountTokensOut);

            // making sure exactly amountTokensOut tokens were sent out
            uint newTokenBalance = _getTokenBalance(token);
            require(
                newTokenBalance == pools[poolPos].balanceToken,
                FEE_ON_TRANSFER_TOKENS_ARENT_SUPPORTED_E
            );
        }
        if (amountCerUsdOut > 0) {
            _safeTransferHelper(cerUsdToken, transferTo, amountCerUsdOut);
        }
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
        if (token != nativeToken && from != address(this)) {
            _safeTransferFrom(token, from, address(this), amount);
        }
    }

    function _safeTransferHelper(address token, address to, uint amount)
        private
    {
        if (to != address(this)) {
            if (token == nativeToken) {
                _safeTransferNative(to, amount);
            } else {
                _safeTransfer(token, to, amount);
            }
        }
    }
    
    function _safeTransfer(
        address token,
        address to,
        uint value
    ) private {
        // bytes4(keccak256(bytes('transfer(address,uint)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            SAFE_TRANSFER_FAILED_R
        );
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint value
    ) private {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            SAFE_TRANSFER_FROM_FAILED_G
        );
    }

    function _safeTransferNative(address to, uint value) private {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, SAFE_TRANSFER_ETH_FAILED_Q);
    }

    function syncTokenBalanceInPool(address token)
        public
        tokenMustExistInPool(token)
        // checkForBotsAndExecuteCronJobs(msg.sender) // TODO: enable on production
    {
        uint poolPos = tokenToPoolPosition[token];
        pools[poolPos].balanceToken = uint112(_getTokenBalance(token));
        
        uint newTotalCerUsdBalance = _getTokenBalance(cerUsdToken);
        pools[poolPos].balanceCerUsd = 
            newTotalCerUsdBalance > totalCerUsdBalance?
                pools[poolPos].balanceCerUsd + uint112(newTotalCerUsdBalance - totalCerUsdBalance):
                pools[poolPos].balanceCerUsd - uint112(totalCerUsdBalance - newTotalCerUsdBalance);

        totalCerUsdBalance = newTotalCerUsdBalance;
    }

    function getCurrent4Hour()
        private
        view
        returns (uint)
    {
        return (block.timestamp / 14400) % NUMBER_OF_4HOUR_INTERVALS;
    }

    function getCurrentFeeBasedOnTrades(address token)
        public
        view
        returns (uint fee)
    {
        return getCurrentFeeBasedOnTrades(tokenToPoolPosition[token]);
    }

    function getCurrentFeeBasedOnTrades(uint poolPos)
        private
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

        // TODO: replace x0.15 to variable updated by admin!!!!

        // TVL x0.15 ---> 1.00%
        // TVL x0.15 - x15 ---> 1.00% - 0.01%
        // TVL x15 ---> 0.01%
        uint volumeMultiplied = last24HourTradeVolumeInCerUSD * 1e18 * 1000;
        uint TVLMultiplied = pools[poolPos].balanceCerUsd * 2 * 150; // x2 because two tokens in pair
        if (volumeMultiplied <= TVLMultiplied) {
            fee = 9900; // 1.00%
        } else if (TVLMultiplied < volumeMultiplied && volumeMultiplied < 100 * TVLMultiplied) {
            fee = 9900 + (volumeMultiplied - TVLMultiplied) / TVLMultiplied;
        } else if (volumeMultiplied > 100 * TVLMultiplied)
        {
            fee = 9999; // 0.01%
        }

        return fee;
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
        uint poolPos = tokenToPoolPosition[token];
        return _getOutput(
            amountTokensIn,
            pools[poolPos].balanceToken,
            pools[poolPos].balanceCerUsd,
            getCurrentFeeBasedOnTrades(poolPos)
        );
    }

    function getOutputExactCerUsdForTokens(address token, uint amountCerUsdIn)
        private
        view
        tokenMustExistInPool(token)
        returns (uint)
    {
        uint poolPos = tokenToPoolPosition[token];
        return _getOutput(
            amountCerUsdIn,
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

    function getInputTokensForExactCerUsd(address token, uint amountCerUsdOut)
        private
        view
        tokenMustExistInPool(token)
        returns (uint)
    {
        uint poolPos = tokenToPoolPosition[token];
        return _getInput(
            amountCerUsdOut,
            pools[poolPos].balanceToken,
            pools[poolPos].balanceCerUsd,
            getCurrentFeeBasedOnTrades(poolPos)
        );
    }

    function getInputCerUsdForExactTokens(address token, uint amountTokensOut)
        private
        view
        tokenMustExistInPool(token)
        returns (uint)
    {
        uint poolPos = tokenToPoolPosition[token];
        return _getInput(
            amountTokensOut,
            pools[poolPos].balanceCerUsd,
            pools[poolPos].balanceToken,
            getCurrentFeeBasedOnTrades(poolPos)
        );
    }

    function _getInput(uint amountOut, uint reservesIn, uint reservesOut, uint poolFee)
        private
        pure
        returns (uint)
    {
        uint amountIn = (reservesIn * amountOut * FEE_DENORM) /
            (poolFee * (reservesOut - amountOut)) + 1; // adding +1 for any rounding trims
        return amountIn;
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

    function getTotalCerUsdBalance()
        public
        view
        returns (uint)
    {
        return totalCerUsdBalance;
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
}