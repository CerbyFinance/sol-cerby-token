// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.11;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ICerbyTokenMinterBurner.sol";
import "./interfaces/ICerbyCronJobs.sol";
import "./interfaces/ICerbyBotDetection.sol";
import "./interfaces/ICerbySwapLP1155V1.sol";
import "./interfaces/IWeth.sol";
import "./CerbyCronJobsExecution.sol";


contract CerbySwapV1 is AccessControlEnumerable, CerbyCronJobsExecution {
    using SafeERC20 for IERC20;

    string constant ALREADY_INITIALIZED_A = "A";
    string constant TOKEN_ALREAD_EXISTS_B = "B";
    string constant TOKEN_DOES_NOT_EXIST_C = "C";
    string constant TRANSACTION_IS_EXPIRED_D = "D";
    string constant FEE_ON_TRANSFER_TOKENS_ARENT_SUPPORTED_E = "E";
    string constant AMOUNT_OF_TOKENS_IN_MUST_BE_LARGER_THAN_ZERO_F = "F"; // not used
    string constant AMOUNT_OF_CERUSD_MUST_BE_LARGER_THAN_ZERO_G = "G"; // not used
    string constant OUTPUT_CERUSD_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_H = "H";
    string constant OUTPUT_TOKENS_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_i = "i";
    string constant OUTPUT_CERUSD_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_J = "J";
    string constant OUTPUT_TOKENS_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_K = "K";
    string constant SWAP_CERUSD_FOR_CERUSD_IS_FORBIDDEN_L = "L";
    string constant ONE_OF_TOKENIN_OR_TOKEN_OUT_IS_WRONG_M = "M";
    string constant POOL_POS_DOES_NOT_EXIST_N = "N";
    string constant AMOUNT_OF_CERUSD_OR_TOKENS_MUST_BE_LARGER_THAN_ZERO_O = "O";
    string constant INVARIANT_K_VALUE_MUST_BE_INCREASED_ON_ANY_TRADE_P = "P";

    Pool[] pools;
    mapping(address => uint) tokenToPoolPosition;
    uint totalCerUsdBalance;

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
    // "0xF3B07F8167b665BA3E2DD29c661DeE3a1da2380a","0x2c4fE51d1Ad5B88cD2cc2F45ad1c0C857f06225e","1000000000000000000000","0","20415641000","0x539FaA851D86781009EC30dF437D794bCd090c8F"
    // "0x2c4fE51d1Ad5B88cD2cc2F45ad1c0C857f06225e","0xF3B07F8167b665BA3E2DD29c661DeE3a1da2380a","1000000000000000000000","0","20415641000","0x539FaA851D86781009EC30dF437D794bCd090c8F"
    */
    address lpErc1155V1 = 0x370a4BA20191804aeEAb8eB39e3ea83D77fEB68d;
    address testCerbyToken = 0x2c4fE51d1Ad5B88cD2cc2F45ad1c0C857f06225e;
    address cerUsdToken = 0xF3B07F8167b665BA3E2DD29c661DeE3a1da2380a;
    address testUsdcToken = 0x2a5E269bF364E347942c464a999D8c8ac2E6CE94;

    address nativeToken;

    uint constant FEE_DENORM = 10000;

    uint constant NUMBER_OF_4HOUR_INTERVALS = 8;
    uint constant MINIMUM_LIQUIDITY = 1000;
    address constant DEAD_ADDRESS = address(0xdead);
    address public feeToBeneficiary = DEAD_ADDRESS;

    bool isInitializedAlready;

    struct Pool {
        address token;
        uint112 balanceToken;
        uint112 balanceCerUsd;
        uint112 lastSqrtKValue;
        uint32[NUMBER_OF_4HOUR_INTERVALS] hourlyTradeVolumeInCerUsd;
    }

    constructor() {
        _setupRole(ROLE_ADMIN, msg.sender);

        feeToBeneficiary = msg.sender;

        // TODO: fill weth, wbnb, wmatic etc
        if (block.chainid == 12345) {
            nativeToken = DEAD_ADDRESS;
        } else if (block.chainid == 98765) {
            nativeToken = DEAD_ADDRESS;
        } 

        nativeToken = 0x14769F96e57B80c66837701DE0B43686Fb4632De; // TODO: update
    }

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

    function testSetupTokens(address _lpErc1155V1, address _testCerbyToken, address _cerUsdToken, address _testUsdcToken, address _nativeToken)
        public
    {
        lpErc1155V1 = _lpErc1155V1;
        testCerbyToken= _testCerbyToken;
        cerUsdToken = _cerUsdToken;
        testUsdcToken = _testUsdcToken;
        nativeToken = _nativeToken;
    }

    function adminInitialize() 
        public
        // onlyRole(ROLE_ADMIN) // TODO: enable on production
    {
        require(
            !isInitializedAlready, 
            ALREADY_INITIALIZED_A
        );
        isInitializedAlready = true;

        // Filling with empty pool 0th position
        uint32[NUMBER_OF_4HOUR_INTERVALS] memory hourlyTradeVolumeInCerUsd;
        pools.push(Pool(
            address(0),
            0,
            0,
            0,
            hourlyTradeVolumeInCerUsd
        ));

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

        IERC20(token).safeTransferFrom(msg.sender, address(this), amountTokensIn);
        ICerbyTokenMinterBurner(cerUsdToken).mintHumanAddress(address(this), amountCerUsdIn);

        // finding out how many tokens router have sent to us
        amountTokensIn = IERC20(token).balanceOf(address(this));
        require(
            amountTokensIn > 0,
            AMOUNT_OF_TOKENS_IN_MUST_BE_LARGER_THAN_ZERO_F
        );

        // create new pool record
        uint112 newSqrtKValue = uint112(sqrt(uint(amountTokensIn) * uint(amountCerUsdIn)));
        uint32[NUMBER_OF_4HOUR_INTERVALS] memory hourlyTradeVolumeInCerUsd;
        Pool memory pool = Pool(
            token,
            uint112(amountTokensIn),
            uint112(amountCerUsdIn),
            newSqrtKValue,
            hourlyTradeVolumeInCerUsd
        );
        pools.push(pool);
        tokenToPoolPosition[token] = poolPos;   
        totalCerUsdBalance += amountCerUsdIn;

        // minting 1000 lp tokens to prevent attack
        ICerbySwapLP1155V1(lpErc1155V1).adminMint(
            DEAD_ADDRESS,
            poolPos,
            MINIMUM_LIQUIDITY
        );

        // minting initial lp tokens
        uint lpAmount = sqrt(uint(amountTokensIn) * uint(amountCerUsdIn)) - MINIMUM_LIQUIDITY;
        ICerbySwapLP1155V1(lpErc1155V1).adminMint(
            transferTo,
            poolPos,
            lpAmount
        );
    }

    function addNativeLiquidity(address transferTo)
        public
        payable
        // checkForBotsAndExecuteCronJobs(msg.sender) // TODO: enable on production
    {
        uint amountTokensIn = msg.value;
        IWeth(nativeToken).deposit{value: amountTokensIn}();

        _addTokenLiquidity(
            address(this),
            nativeToken,
            amountTokensIn,
            transferTo
        );
    }

    function removeNativeLiquidity(uint amountLpTokensBalanceToBurn, address transferTo)
        public
        // checkForBotsAndExecuteCronJobs(msg.sender) // TODO: enable on production
    {
        uint amountTokensOut = _removeTokenLiquidity(
            msg.sender,
            nativeToken,
            amountLpTokensBalanceToBurn,
            address(this)
        );
        IWeth(nativeToken).withdraw(amountTokensOut);
        payable(transferTo).transfer(amountTokensOut);
    }

    function addTokenLiquidity(address token, uint amountTokensIn, address transferTo)
        public
        // checkForBotsAndExecuteCronJobs(msg.sender) // TODO: enable on production
    {
        _addTokenLiquidity(
            msg.sender,
            token,
            amountTokensIn,
            transferTo
        );        
    }

    function _addTokenLiquidity(address fromAddress, address token, uint amountTokensIn, address transferTo)
        private
        tokenMustExistInPool(token)
    {
        uint poolPos = tokenToPoolPosition[token];

        if (fromAddress != address(this)) {
            IERC20(token).safeTransferFrom(fromAddress, address(this), amountTokensIn);
        }

        // finding out how many tokens we've actually received
        uint newTokenBalance = IERC20(token).balanceOf(address(this));
        amountTokensIn = newTokenBalance - pools[poolPos].balanceToken;
        require(
            amountTokensIn > 0,
            AMOUNT_OF_TOKENS_IN_MUST_BE_LARGER_THAN_ZERO_F
        );

        // finding out if for some reason we've received cerUSD tokens as well
        uint newTotalCerUsdBalance = IERC20(cerUsdToken).balanceOf(address(this));
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
        uint totalLPSupply = ICerbySwapLP1155V1(lpErc1155V1).totalSupply(poolPos);
        uint lpAmount = (amountTokensIn * totalLPSupply) / pools[poolPos].balanceToken;
        ICerbySwapLP1155V1(lpErc1155V1).adminMint(
            transferTo,
            poolPos,
            lpAmount
        );

        // minting trade fees
        uint amountLpTokensToMintAsFee = _getMintFeeLiquidityAmount(lastSqrtKValue, newSqrtKValue, totalLPSupply);
        if (amountLpTokensToMintAsFee > 0) {
            ICerbySwapLP1155V1(lpErc1155V1).adminMint(feeToBeneficiary, poolPos, amountLpTokensToMintAsFee);
        }
    }

    function removeTokenLiquidity(address token, uint amountLpTokensBalanceToBurn, address transferTo)
        public
        // checkForBotsAndExecuteCronJobs(msg.sender) // TODO: enable on production
        returns (uint)
    {
        return _removeTokenLiquidity(msg.sender, token, amountLpTokensBalanceToBurn, transferTo);
    }

    function _removeTokenLiquidity(address fromAddress, address token, uint amountLpTokensBalanceToBurn, address transferTo)
        private
        tokenMustExistInPool(token)
        returns (uint)
    {
        uint poolPos = tokenToPoolPosition[token];

        if (fromAddress != address(this)) {
            bytes memory data;
            ICerbySwapLP1155V1(lpErc1155V1).safeTransferFrom(fromAddress, address(this), poolPos, amountLpTokensBalanceToBurn, data);
        }

        // finding out if for some reason we've received tokens
        uint oldTokenBalance = IERC20(token).balanceOf(address(this));
        uint amountTokensIn = oldTokenBalance - pools[poolPos].balanceToken;

        // finding out if for some reason we've received cerUSD tokens as well
        uint amountCerUsdIn = IERC20(cerUsdToken).balanceOf(address(this)) - totalCerUsdBalance;

        // calculating amount of tokens to transfer
        uint totalLPSupply = ICerbySwapLP1155V1(lpErc1155V1).totalSupply(poolPos);
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
            ICerbySwapLP1155V1(lpErc1155V1).burn(poolPos, amountLpTokensBalanceToBurn);

            // burning cerUSD
            ICerbyTokenMinterBurner(cerUsdToken).burnHumanAddress(address(this), amountCerUsdToBurn);

        
            // minting trade fees
            uint amountLpTokensToMintAsFee = 
                _getMintFeeLiquidityAmount(lastSqrtKValue, newSqrtKValue, totalLPSupply);
            if (amountLpTokensToMintAsFee > 0) {
                ICerbySwapLP1155V1(lpErc1155V1).
                    adminMint(feeToBeneficiary, poolPos, amountLpTokensToMintAsFee);
            }
        }

        // transfering tokens
        if (transferTo != address(this))
        {
            IERC20(token).safeTransfer(transferTo, amountTokensOut);
        }
        uint newTokenBalance = IERC20(token).balanceOf(address(this));
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

    function swapExactNativeForTokens(
        address tokenOut,
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
        uint amountTokensIn = msg.value;
        IWeth(nativeToken).deposit{value: amountTokensIn}();

        return _swapExactTokensForTokens(
            address(this),
            nativeToken,
            tokenOut,
            amountTokensIn,
            minAmountTokensOut,
            transferTo
        );
    }

    function swapNativeForExactTokens(
        address tokenOut,
        uint amountTokensOut,
        uint expireTimestamp,
        address transferTo
    )
        public
        payable
        // checkForBotsAndExecuteCronJobs(msg.sender) // TODO: enable on production
        transactionIsNotExpired(expireTimestamp)
        returns (uint, uint)
    {
        uint maxAmountTokensIn = msg.value;
        IWeth(nativeToken).deposit{value: maxAmountTokensIn}();
        
        (uint amountTokensIn, ) = _swapTokensForExactTokens(
            address(this),
            nativeToken,
            tokenOut,
            amountTokensOut,
            maxAmountTokensIn,
            transferTo
        );

        uint remainingNative = maxAmountTokensIn - amountTokensOut;
        IWeth(nativeToken).withdraw(remainingNative);

        payable(transferTo).transfer(remainingNative);
        return (amountTokensIn, amountTokensOut);
    }

    function swapTokensForExactNative(
        address tokenIn,
        uint maxAmountTokensIn,
        uint amountTokensOut,
        uint expireTimestamp,
        address transferTo
    )
        public
        payable
        // checkForBotsAndExecuteCronJobs(msg.sender) // TODO: enable on production
        transactionIsNotExpired(expireTimestamp)
        returns (uint, uint)
    {
        (uint amountTokensIn, ) = _swapTokensForExactTokens(
            msg.sender,
            tokenIn,
            nativeToken,
            amountTokensOut,
            maxAmountTokensIn,
            address(this)
        );

        IWeth(nativeToken).withdraw(amountTokensOut);

        payable(transferTo).transfer(amountTokensOut);
        return (amountTokensIn, amountTokensOut);
    }

    function swapExactTokensForNative(
        address tokenIn,
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
        (, uint amountTokensOut) = _swapExactTokensForTokens(
            address(this),
            tokenIn,
            nativeToken,
            amountTokensIn,
            minAmountTokensOut,
            transferTo
        );   

        IWeth(nativeToken).withdraw(amountTokensOut);

        payable(transferTo).transfer(amountTokensOut);
        return (amountTokensIn, amountTokensOut);
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
        // checkForBotsAndExecuteCronJobs(msg.sender) // TODO: enable on production
        transactionIsNotExpired(expireTimestamp)
        returns (uint, uint)
    {
        return _swapExactTokensForTokens(
            msg.sender,
            tokenIn,
            tokenOut,
            amountTokensIn,
            minAmountTokensOut,
            transferTo
        );
    }

    function _swapExactTokensForTokens(
        address fromAddress,
        address tokenIn,
        address tokenOut,
        uint amountTokensIn,
        uint minAmountTokensOut,
        address transferTo    
    )
        private
        returns (uint, uint)
    {
        uint amountTokensOut;
        if (tokenIn != cerUsdToken && tokenOut == cerUsdToken) {

            // getting amountTokensOut
            amountTokensOut = getOutputExactTokensForCerUsd(tokenIn, amountTokensIn);
            require(
                amountTokensOut >= minAmountTokensOut,
                OUTPUT_CERUSD_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_H
            );

            // actually transferring the tokens to the pool
            IERC20(tokenIn).safeTransferFrom(fromAddress, address(this), amountTokensIn);

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
            IERC20(tokenIn).transferFrom(fromAddress, address(this), amountTokensIn);

            // swapping cerUSD ---> YYY
            swap(
                tokenOut,
                amountTokensOut,
                0,
                transferTo
            );
        } else if (tokenIn != cerUsdToken && tokenIn != cerUsdToken) {

            // getting amountTokensOut=
            uint amountCerUsdOut = getOutputExactTokensForCerUsd(tokenIn, amountTokensIn);

            amountTokensOut = getOutputExactCerUsdForTokens(tokenOut, amountCerUsdOut);
            require(
                amountTokensOut >= minAmountTokensOut,
                OUTPUT_TOKENS_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_i
            );

            // actually transferring the tokens to the pool
            IERC20(tokenIn).safeTransferFrom(fromAddress, address(this), amountTokensIn);

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
        // checkForBotsAndExecuteCronJobs(msg.sender) // TODO: enable on production
        transactionIsNotExpired(expireTimestamp)
        returns (uint, uint)
    {
        return _swapTokensForExactTokens(
            msg.sender,
            tokenIn,
            tokenOut,
            amountTokensOut,
            maxAmountTokensIn,
            transferTo
        );        
    }

    function _swapTokensForExactTokens(
        address fromAddress,
        address tokenIn,
        address tokenOut,
        uint amountTokensOut,
        uint maxAmountTokensIn,
        address transferTo
    )
        private
        returns (uint, uint)
    {
        uint amountTokensIn;
        if (tokenIn != cerUsdToken && tokenOut == cerUsdToken) {

            // getting amountTokensOut
            amountTokensIn = getInputTokensForExactCerUsd(tokenIn, amountTokensOut);
            require(
                amountTokensIn <= maxAmountTokensIn,
                OUTPUT_TOKENS_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_K
            );

            // actually transferring the tokens to the pool
            IERC20(tokenIn).safeTransferFrom(fromAddress, address(this), amountTokensIn);

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

            // actually transferring the tokens to the pool
            IERC20(tokenIn).safeTransferFrom(fromAddress, address(this), amountTokensIn);

            // swapping cerUSD ---> YYY
            swap(
                tokenOut,
                amountTokensOut,
                0,
                transferTo
            );
        } else if (tokenIn != cerUsdToken && tokenOut != cerUsdToken) {

            // getting amountTokensOut
            uint amountCerUsdOut = getInputCerUsdForExactTokens(tokenOut, amountTokensOut);

            amountTokensIn = getInputTokensForExactCerUsd(tokenIn, amountCerUsdOut);
            require(
                amountTokensIn <= maxAmountTokensIn,
                OUTPUT_TOKENS_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_K
            );

            // actually transferring the tokens to the pool
            IERC20(tokenIn).safeTransferFrom(fromAddress, address(this), amountTokensIn);

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
        tokenMustExistInPool(token)
    {
        uint poolPos = tokenToPoolPosition[token];

        // finding out how many amountCerUsdIn we received
        uint newTotalCerUsdBalance = IERC20(cerUsdToken).balanceOf(address(this));
        uint amountCerUsdIn = newTotalCerUsdBalance - totalCerUsdBalance;

        // finding out how many amountTokensIn we received
        uint oldTokenBalance = IERC20(token).balanceOf(address(this));
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

            // updating pool values
            totalCerUsdBalance = totalCerUsdBalance + amountCerUsdIn - amountCerUsdOut;
            pools[poolPos].balanceCerUsd = 
                pools[poolPos].balanceCerUsd + uint112(amountCerUsdIn) - uint112(amountCerUsdOut);
            pools[poolPos].balanceToken = 
                pools[poolPos].balanceToken + uint112(amountTokensIn) - uint112(amountTokensOut);

            // calculating new K value including trade fees (multiplied by FEE_DENORM^2)
            uint afterKValueDenormed = 
                (uint(pools[poolPos].balanceCerUsd) * FEE_DENORM - amountCerUsdIn * (FEE_DENORM - fee)) * 
                (uint(pools[poolPos].balanceToken) * FEE_DENORM - amountTokensIn * (FEE_DENORM - fee));
            require(
                afterKValueDenormed >= beforeKValueDenormed,
                INVARIANT_K_VALUE_MUST_BE_INCREASED_ON_ANY_TRADE_P
            );
        }

        // updating 4hour trade pool values
        uint current4Hour = getCurrent4Hour();
        uint next4Hour = (getCurrent4Hour() + 1) % pools[poolPos].hourlyTradeVolumeInCerUsd.length;
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
        if (transferTo != address(this)) {
            if (amountTokensOut > 0) {
                IERC20(token).safeTransfer(transferTo, amountTokensOut);

                // making sure exactly amountTokensOut tokens were sent out
                uint newTokenBalance = IERC20(token).balanceOf(address(this));
                require(
                    newTokenBalance == pools[poolPos].balanceToken,
                    FEE_ON_TRANSFER_TOKENS_ARENT_SUPPORTED_E
                );
            }
            if (amountCerUsdOut > 0) {
                // since cerUSD is our token, we don't need to use safeTransfer function
                IERC20(cerUsdToken).transfer(transferTo, amountCerUsdOut);
            }
        }
    }

    function syncTokenBalanceInPool(address token)
        public
        tokenMustExistInPool(token)
        // checkForBotsAndExecuteCronJobs(msg.sender) // TODO: enable on production
    {
        uint poolPos = tokenToPoolPosition[token];
        pools[poolPos].balanceToken = uint112(IERC20(token).balanceOf(address(this)));
        
        uint newTotalCerUsdBalance = IERC20(cerUsdToken).balanceOf(address(this));
        pools[poolPos].balanceCerUsd = 
            newTotalCerUsdBalance > totalCerUsdBalance?
                pools[poolPos].balanceCerUsd + uint112(newTotalCerUsdBalance - totalCerUsdBalance):
                pools[poolPos].balanceCerUsd - uint112(totalCerUsdBalance - newTotalCerUsdBalance);

        totalCerUsdBalance = newTotalCerUsdBalance;
    }

    function getCurrent4Hour()
        public
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
            (poolFee * (reservesOut - amountOut)) + 1;
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


    function testGetTokenToPoolPosition(address token) 
        public
        view
        returns (uint)
    {
        return tokenToPoolPosition[token];
    }
}