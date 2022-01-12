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
import "./CerbySwapLP1155V1.sol";


contract CerbySwapV1 is AccessControlEnumerable, CerbyCronJobsExecution {
    using SafeERC20 for IERC20;

    string constant ALREADY_INITIALIZED_A = "A";
    string constant TOKEN_ALREAD_EXISTS_E = "E";
    string constant TOKEN_DOES_NOT_EXIST_N = "N";
    string constant TRANSACTION_IS_EXPIRED_T = "T";
    string constant FEE_ON_TRANSFER_TOKENS_ARENT_SUPPORTED_F = "F";
    string constant AMOUNT_OF_TOKENS_IN_MUST_BE_LARGER_THAN_ZERO_Z = "Z";
    string constant AMOUNT_OF_CERUSD_MUST_BE_LARGER_THAN_ZERO_U = "U";
    string constant OUTPUT_CERUSD_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_M = "M";
    string constant OUTPUT_TOKENS_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_N = "N";
    string constant OUTPUT_CERUSD_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_X = "X";
    string constant OUTPUT_TOKENS_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_Y = "Y";

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
    // "0xCd300dd54345F48Ba108Df3D792B6c2Dbb17edD2","0xde402E9D305bAd483d47bc858cC373c5a040A62D","10000000000000000000000","0","2041564156"
    // "0xde402E9D305bAd483d47bc858cC373c5a040A62D","0xCd300dd54345F48Ba108Df3D792B6c2Dbb17edD2","1000000000000000000000","0","20415641
    */
    address lpErc1155V1 = 0xE94EFBCaA00665C8faA47E18741DA9f212a15c20;
    address testCerbyToken = 0xCd300dd54345F48Ba108Df3D792B6c2Dbb17edD2;
    address cerUsdToken = 0x04D7000CC826349A872757D82b3E0F68a713B3c5;
    address testUsdcToken = 0xde402E9D305bAd483d47bc858cC373c5a040A62D;

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
            TOKEN_DOES_NOT_EXIST_N
        );
        _;
    }

    modifier tokenDoesNotExistInPool(address token)
    {
        require(
            tokenToPoolPosition[token] == 0 && token != cerUsdToken,
            TOKEN_ALREAD_EXISTS_E
        );
        _;
    }

    modifier transactionIsNotExpired(uint expireTimestamp)
    {
        require(
            block.timestamp <= expireTimestamp,
            TRANSACTION_IS_EXPIRED_T
        );
        _;
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
        ICerbyTokenMinterBurner(cerUsdToken).mintHumanAddress(address(this), amountTokensIn);

        // finding out how many tokens router have sent to us
        amountTokensIn = IERC20(token).balanceOf(address(this));
        require(
            amountTokensIn > 0,
            AMOUNT_OF_TOKENS_IN_MUST_BE_LARGER_THAN_ZERO_Z
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
            AMOUNT_OF_TOKENS_IN_MUST_BE_LARGER_THAN_ZERO_Z
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
        tokenMustExistInPool(token)
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
            FEE_ON_TRANSFER_TOKENS_ARENT_SUPPORTED_F
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
        tokenMustExistInPool(nativeToken)
        transactionIsNotExpired(expireTimestamp)
        returns (uint)
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
        tokenMustExistInPool(nativeToken)
        transactionIsNotExpired(expireTimestamp)
        returns (uint)
    {
        uint maxAmountTokensIn = msg.value;
        IWeth(nativeToken).deposit{value: maxAmountTokensIn}();
        
        _swapTokensForExactTokens(
            address(this),
            nativeToken,
            tokenOut,
            maxAmountTokensIn,
            amountTokensOut,
            transferTo
        );

        uint remainingNative = maxAmountTokensIn - amountTokensOut;
        IWeth(nativeToken).withdraw(remainingNative);

        payable(transferTo).transfer(remainingNative);
        return amountTokensOut;
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
        tokenMustExistInPool(nativeToken)
        transactionIsNotExpired(expireTimestamp)
        returns (uint)
    {
        _swapTokensForExactTokens(
            msg.sender,
            tokenIn,
            nativeToken,
            maxAmountTokensIn,
            amountTokensOut,
            address(this)
        );

        IWeth(nativeToken).withdraw(amountTokensOut);

        payable(transferTo).transfer(amountTokensOut);
        return amountTokensOut;
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
        tokenMustExistInPool(nativeToken)
        transactionIsNotExpired(expireTimestamp)
        returns (uint)
    {
        uint amountTokensOut = _swapExactTokensForTokens(
            address(this),
            tokenIn,
            nativeToken,
            amountTokensIn,
            minAmountTokensOut,
            transferTo
        );   

        IWeth(nativeToken).withdraw(amountTokensOut);

        payable(transferTo).transfer(amountTokensOut);
        return amountTokensOut;
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
        tokenMustExistInPool(tokenIn)
        transactionIsNotExpired(expireTimestamp)
        returns (uint)
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
        returns (uint)
    {
        if (fromAddress != address(this))
        {
            IERC20(tokenIn).safeTransferFrom(fromAddress, address(this), amountTokensIn);
        }

        uint outputTokensOut;
        if (tokenIn == cerUsdToken && tokenOut != cerUsdToken) {
            // swapping cerUSD ---> YYY
            outputTokensOut = _swapExactCerUsdForTokens(
                tokenOut,
                minAmountTokensOut,
                transferTo
            );
        } else if (tokenIn != cerUsdToken && tokenOut == cerUsdToken) {
            // swapping XXX ---> cerUSD
            outputTokensOut = _swapExactTokensForCerUsd(
                tokenIn,
                minAmountTokensOut,
                transferTo
            );
        } else {
            // swapping XXX ---> cerUSD
            _swapExactTokensForCerUsd(
                tokenIn,
                0,
                address(this)
            );

            // swapping cerUSD ---> YYY
            outputTokensOut = _swapExactCerUsdForTokens(
                tokenOut,
                minAmountTokensOut,
                transferTo
            );
        }
        return outputTokensOut;
    }

    function swapTokensForExactTokens(
        address tokenIn,
        address tokenOut,
        uint maxAmountTokensIn,
        uint amountTokensOut,
        uint expireTimestamp,
        address transferTo
    )
        public
        // checkForBotsAndExecuteCronJobs(msg.sender) // TODO: enable on production
        tokenMustExistInPool(tokenIn)
        transactionIsNotExpired(expireTimestamp)
        returns (uint)
    {
        return _swapTokensForExactTokens(
            msg.sender,
            tokenIn,
            tokenOut,
            maxAmountTokensIn,
            amountTokensOut,
            transferTo
        );        
    }

    function _swapTokensForExactTokens(
        address fromAddress,
        address tokenIn,
        address tokenOut,
        uint maxAmountTokensIn,
        uint amountTokensOut,
        address transferTo
    )
        private
        returns (uint)
    {
        uint amountTokensIn;
        uint outputTokensOut;
        if (tokenIn == cerUsdToken && tokenOut != cerUsdToken) {
            // getting amountTokensIn based on exact amountTokensOut on cerUsd/TokenOut pool
            amountTokensIn = 
                getInputCerUsdForExactTokens(tokenToPoolPosition[tokenOut], amountTokensOut);
            require(
                amountTokensIn <= maxAmountTokensIn,
                OUTPUT_CERUSD_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_X
            );

            if (fromAddress != address(this))
            {
                IERC20(tokenIn).safeTransferFrom(fromAddress, address(this), amountTokensIn);
            }

            // swapping cerUSD ---> YYY
            outputTokensOut = _swapExactCerUsdForTokens(
                tokenOut,
                0,
                transferTo
            );
        } else if (tokenIn != cerUsdToken && tokenOut == cerUsdToken) {
            // getting amountTokensIn based on exact amountTokensOut on TokenIn/CerUsd pool
            amountTokensIn = 
                getInputTokensForExactCerUsd(tokenToPoolPosition[tokenIn], amountTokensOut);
            require(
                amountTokensIn <= maxAmountTokensIn,
                OUTPUT_TOKENS_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_Y
            );

            if (fromAddress != address(this))
            {
                IERC20(tokenIn).safeTransferFrom(fromAddress, address(this), amountTokensIn);
            }            

            // swapping XXX ---> cerUSD
            outputTokensOut = _swapExactTokensForCerUsd(
                tokenIn,
                0,
                transferTo
            );
        } else if (tokenIn != cerUsdToken && tokenOut != cerUsdToken) {
            // getting amountCerUsdIn based on exact amountTokensOut on cerUSD/TokenOut pool
            uint amountCerUsdIn = 
                getInputCerUsdForExactTokens(tokenToPoolPosition[tokenOut], amountTokensOut);

            // getting amountTokensIn based on exact amountCerUsdIn on TokenIn/CerUsd pool
            amountTokensIn = 
                getInputTokensForExactCerUsd(tokenToPoolPosition[tokenIn], amountCerUsdIn);
            require(
                amountTokensIn <= maxAmountTokensIn,
                OUTPUT_TOKENS_AMOUNT_IS_MORE_THAN_MAXIMUM_SPECIFIED_Y
            );

            if (fromAddress != address(this))
            {
                IERC20(tokenIn).safeTransferFrom(fromAddress, address(this), amountTokensIn);
            }

            // swapping XXX ---> cerUSD
            _swapExactTokensForCerUsd(
                tokenIn,
                0,
                address(this)
            );

            // swapping cerUSD ---> YYY
            outputTokensOut = _swapExactCerUsdForTokens(
                tokenOut,
                0,
                transferTo
            );
        }
        return outputTokensOut;
    }

    function _swapExactTokensForCerUsd(
        address tokenIn,
        uint minAmountCerUsdOut,
        address transferTo
    )
        private
        returns (uint)
    {
        uint poolPos = tokenToPoolPosition[tokenIn];

        // finding out how many tokens router have sent to us
        uint newTokenBalance = IERC20(tokenIn).balanceOf(address(this));
        uint amountTokensIn = newTokenBalance - pools[poolPos].balanceToken;
        require(
            amountTokensIn > 0,
            AMOUNT_OF_TOKENS_IN_MUST_BE_LARGER_THAN_ZERO_Z
        );

        // finding out if for some reason we've received cerUSD tokens as well
        uint newTotalCerUsdBalance = IERC20(cerUsdToken).balanceOf(address(this));
        uint amountCerUsdIn = newTotalCerUsdBalance - totalCerUsdBalance;

        // calculating the amount we have to send to user
        uint amountCerUsdOut = getOutputExactTokensForCerUsd(poolPos, amountTokensIn);
        require(
            amountCerUsdOut >= minAmountCerUsdOut,
            OUTPUT_CERUSD_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_M
        );

        // updating pool values
        totalCerUsdBalance = newTotalCerUsdBalance;
        pools[poolPos].balanceCerUsd = 
            pools[poolPos].balanceCerUsd + uint112(amountCerUsdIn) - uint112(amountCerUsdOut);
        pools[poolPos].balanceToken = uint112(newTokenBalance);

        // updating 4hour trade pool values
        uint current4Hour = getCurrent4Hour();
        uint next4Hour = (current4Hour + 1) % NUMBER_OF_4HOUR_INTERVALS;
        unchecked {
            // wrapping any uint32 overflows
            // stores in USD value
            pools[poolPos].hourlyTradeVolumeInCerUsd[current4Hour] += uint32(amountCerUsdOut / 1e18);
        }

        // clearing next 4hour trade value
        if (pools[poolPos].hourlyTradeVolumeInCerUsd[next4Hour] > 0)
        {
            pools[poolPos].hourlyTradeVolumeInCerUsd[next4Hour] = 0;
        }

        // transferring cerUSD tokens
        if (transferTo != address(this)) {
            IERC20(cerUsdToken).safeTransfer(transferTo, amountCerUsdOut);
        }

        return amountCerUsdOut;
    }

    function _swapExactCerUsdForTokens(
        address tokenOut,
        uint minAmountTokenOut,
        address transferTo
    )
        private
        returns (uint)
    {
        uint poolPos = tokenToPoolPosition[tokenOut];

        // finding out how many cerUSD tokens router have sent to us
        uint newTotalCerUsdBalance = IERC20(cerUsdToken).balanceOf(address(this));
        uint amountCerUsdIn = newTotalCerUsdBalance - totalCerUsdBalance;
        require(
            amountCerUsdIn > 0,
            AMOUNT_OF_CERUSD_MUST_BE_LARGER_THAN_ZERO_U
        );

        // finding out if for some reason we've received tokens as well
        uint oldTokenBalance = IERC20(tokenOut).balanceOf(address(this));
        uint amountTokensIn = oldTokenBalance - pools[poolPos].balanceToken;

        // calculating amount of tokens to be sent to user
        uint amountTokensOut = getOutputExactCerUsdForTokens(poolPos, amountCerUsdIn);
        require(
            amountTokensOut >= minAmountTokenOut,
            OUTPUT_TOKENS_AMOUNT_IS_LESS_THAN_MINIMUM_SPECIFIED_N
        );

        // updating pool values
        totalCerUsdBalance = newTotalCerUsdBalance;
        pools[poolPos].balanceCerUsd = pools[poolPos].balanceCerUsd + uint112(amountCerUsdIn);
        pools[poolPos].balanceToken = 
            pools[poolPos].balanceToken + uint112(amountTokensIn) - uint112(amountTokensOut);

        // updating 4hour trade pool values
        uint current4Hour = getCurrent4Hour();
        uint next4Hour = (getCurrent4Hour() + 1) % pools[poolPos].hourlyTradeVolumeInCerUsd.length;
        unchecked {
            // wrapping any uint32 overflows
            // stores in USD value
            pools[poolPos].hourlyTradeVolumeInCerUsd[current4Hour] += uint32(amountCerUsdIn / 1e18);
        }

        // clearing next 4hour trade value
        if (pools[poolPos].hourlyTradeVolumeInCerUsd[next4Hour] > 0)
        {
            pools[poolPos].hourlyTradeVolumeInCerUsd[next4Hour] = 0;
        }

        // transferring tokens from contract to user
        if (transferTo != address(this)) {
            IERC20(tokenOut).safeTransfer(transferTo, amountTokensOut);
        }
        uint newTokenBalance = IERC20(tokenOut).balanceOf(address(this));
        require(
            newTokenBalance == pools[poolPos].balanceToken,
            FEE_ON_TRANSFER_TOKENS_ARENT_SUPPORTED_F
        );

        return amountTokensOut;
    }

    function syncTokenBalanceInPool(address token)
        public
        tokenMustExistInPool(token)
        // checkForBotsAndExecuteCronJobs(msg.sender) // TODO: enable on production
    {
        uint poolPos = tokenToPoolPosition[token];
        pools[poolPos].balanceToken = uint112(IERC20(token).balanceOf(address(this)));
        totalCerUsdBalance = IERC20(cerUsdToken).balanceOf(address(this));
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
            fee = 9900;
        } else if (TVLMultiplied < volumeMultiplied && volumeMultiplied < 100 * TVLMultiplied) {
            fee = 9900 + (volumeMultiplied - TVLMultiplied) / TVLMultiplied;
        } else if (volumeMultiplied > 100 * TVLMultiplied)
        {
            fee = 9999;
        }

        return fee;
    }

    function getOutputExactTokensForCerUsd(uint poolPos, uint amountTokensIn)
        public
        view
        returns (uint)
    {
        return _getOutput(
            amountTokensIn,
            pools[poolPos].balanceToken,
            pools[poolPos].balanceCerUsd,
            getCurrentFeeBasedOnTrades(poolPos)
        );
    }

    function getOutputExactCerUsdForTokens(uint poolPos, uint amountCerUsdIn)
        public
        view
        returns (uint)
    {
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

    function getInputTokensForExactCerUsd(uint poolPos, uint amountCerUsdOut)
        public
        view
        returns (uint)
    {
        return _getInput(
            amountCerUsdOut,
            pools[poolPos].balanceToken,
            pools[poolPos].balanceCerUsd,
            getCurrentFeeBasedOnTrades(poolPos)
        );
    }

    function getInputCerUsdForExactTokens(uint poolPos, uint amountTokensOut)
        public
        view
        returns (uint)
    {
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