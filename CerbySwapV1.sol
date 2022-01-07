// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.11;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./openzeppelin/security/ReentrancyGuard.sol";
import "./openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ICerbyTokenMinterBurner.sol";

struct Pool {
    address token;
    uint112 balanceToken;
    uint112 balanceCerUsd;
    int112 debitCerUsd;
    uint16 fee;
}

contract CerbySwapV1 is AccessControlEnumerable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    Pool[] public pools;
    mapping(address => uint) public tokenToPoolPosition;

    address constant cerUsdContract = 0x3B69b8C5c6a4c8c2a90dc93F3B0238BF70cC9640;
    uint16 constant FEE_DENORM = 10000;
    uint16 constant DEFAULT_FEE = 9985; // 0.15% per transaction XXX <--> cerUSD

    constructor() {
        _setupRole(ROLE_ADMIN, msg.sender);

        // Filling with empty pool 0th position
        createPool(
            address(0),
            0,
            0,
            0
        );

        address cerbyToken = 0xE7126C0Fb4B1f5F79E5Bbec3948139dCF348B49C;
        createPool(
            cerbyToken,
            1e18 * 1e6,
            1e18 * 3e5,
            DEFAULT_FEE
        );
    }

    modifier tokenMustExistInPool(address token)
    {
        require(
            tokenToPoolPosition[token] > 0 && token != cerUsdContract,
            "CS1: Wrong token"
        );
        _;
    }

    modifier tokenDoesNotExistInPool(address token)
    {
        require(
            tokenToPoolPosition[token] == 0 && token != cerUsdContract,
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
        sync(token);
        _;
    }

    modifier safeTransferTokensNeeded(address token, uint amount)
    {
        if (token != cerUsdContract)
        {
            uint oldBalance = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            uint newBalance = IERC20(token).balanceOf(address(this));
            require(
                newBalance >= oldBalance + amount,
                "CS1: Fee-on-transfer tokens aren't supported"
            );
        } else {
            IERC20(token).transferFrom(msg.sender, address(this), amount);
        }
        _;
    }

    function adminUpdateFee(address token, uint16 newFee)
        public
        onlyRole(ROLE_ADMIN)
        tokenMustExistInPool(token)
    {
        uint poolPos = tokenToPoolPosition[token];
        pools[poolPos].fee = newFee;
    }

    // TODO: add remove pool or disable pool to allow remove liquidity only

    function createPool(address token, uint112 addTokenAmount, uint112 mintCerUsdAmount, uint16 fee)
        public
        nonReentrant()
        poolMustBeSynced(token)
        tokenDoesNotExistInPool(token)
        safeTransferTokensNeeded(token, addTokenAmount)
    {
        require(
            fee == DEFAULT_FEE, // TODO: add other values
            "CS1: Incorrect fee provided"
        );

        ICerbyTokenMinterBurner(cerUsdContract).mintHumanAddress(address(this), mintCerUsdAmount);

        // Admins can create official pools with no limit on selling
        // Users can create regular pools where they can't sell more than bought
        int112 newCerUsdDebit = hasRole(ROLE_ADMIN, msg.sender)? int112(mintCerUsdAmount): int112(0);
        pools.push(
            Pool(
                token,
                addTokenAmount,
                mintCerUsdAmount,
                newCerUsdDebit,
                fee
            )
        );
        tokenToPoolPosition[token] = pools.length - 1;

        // TODO: mint LP tokens
        // TODO: record current debit/credit to LP position

        updateTokenBalanceAndCheckKValue(tokenToPoolPosition[token], token);
    }


    function addTokenLiquidity(address token, uint addTokenAmount)
        public
        nonReentrant()
        poolMustBeSynced(token)
        tokenMustExistInPool(token)
        safeTransferTokensNeeded(token, addTokenAmount)
    {
        uint poolPos = tokenToPoolPosition[token];
        uint mintCerUsdAmount = 
            (addTokenAmount * pools[poolPos].balanceCerUsd) / pools[poolPos].balanceToken;
        ICerbyTokenMinterBurner(cerUsdContract).mintHumanAddress(address(this), mintCerUsdAmount);

        // TODO: mint LP tokens
        // TODO: record current debit/credit to LP position
        // TODO: check if user modified transfer function

        updateTokenBalanceAndCheckKValue(poolPos, token);
    }

    function removeTokenLiquidity(address token, uint removeTokenAmount)
        public
        nonReentrant()
        poolMustBeSynced(token)
        tokenMustExistInPool(token)
    {
        // TODO: burn LP tokens
        // TODO: if debit > credit return cerUSD additionally
        // TODO: if debit < credit return reduced tokenAmount

        removeTokenAmount;
        updateTokenBalanceAndCheckKValue(tokenToPoolPosition[token], token);
    }

    // TODO: add swapTokenToExactCerUSD XXX --> cerUSD
    // TODO: add swapCerUsdToExactToken cerUSD --> YYY
    // TODO: add swapExactTokenToToken XXX --> cerUSD --> YYY (XXX != YYY)
    // TODO: add swapTokenToExactToken XXX --> cerUSD --> YYY (XXX != YYY)
    
    function swapExactTokenToCerUsd(
        address tokenIn,
        uint112 amountTokenIn,
        uint112 minAmountCerUsdOut,
        uint32 expireTimestamp
    )
        public
        nonReentrant()
        poolMustBeSynced(tokenIn)
        tokenMustExistInPool(tokenIn)
        transactionIsNotExpired(expireTimestamp)
        safeTransferTokensNeeded(tokenIn, amountTokenIn)
    {
        uint poolPos = tokenToPoolPosition[tokenIn];
        uint increaseTokenBalance = 
            IERC20(tokenIn).balanceOf(address(this)) - pools[poolPos].balanceToken;

        uint112 outputCerUsdAmount = getOutputExactTokensForCerUsd(poolPos, increaseTokenBalance);
        require(
            outputCerUsdAmount >= minAmountCerUsdOut,
            "CS1: Output amount less than minimum specified"
        );

        require(
            // For user-created pools you can't sell more than bought
            // For official pools - no limits
            pools[poolPos].debitCerUsd - int112(outputCerUsdAmount) > 0,
            "CS1: Can't sell more than bought"
        );

        pools[poolPos].debitCerUsd -= int112(outputCerUsdAmount);
        pools[poolPos].balanceCerUsd -= outputCerUsdAmount;
        pools[poolPos].balanceToken += amountTokenIn;

        IERC20(cerUsdContract).transfer(msg.sender, outputCerUsdAmount);

        updateTokenBalanceAndCheckKValue(poolPos, tokenIn);
    }

    function swapExactCerUsdForToken(
        address tokenOut,
        uint amountCerUsdIn,
        uint minAmountTokenOut,
        uint expireTimestamp
    )
        public
        nonReentrant()
        poolMustBeSynced(tokenOut)
        tokenMustExistInPool(tokenOut)
        transactionIsNotExpired(expireTimestamp)
        safeTransferTokensNeeded(cerUsdContract, amountCerUsdIn)
    {
        uint poolPos = tokenToPoolPosition[tokenOut];
        uint112 increaseCerUsdBalance = 
            uint112(IERC20(cerUsdContract).balanceOf(address(this))) - pools[poolPos].balanceCerUsd;

        uint112 outputTokenAmount = getOutputExactCerUsdForToken(poolPos, increaseCerUsdBalance);
        require(
            outputTokenAmount >= minAmountTokenOut,
            "CS1: Output amount less than minimum specified"
        );

        pools[poolPos].debitCerUsd += int112(increaseCerUsdBalance);
        pools[poolPos].balanceCerUsd += increaseCerUsdBalance;
        pools[poolPos].balanceToken -= outputTokenAmount;

        IERC20(tokenOut).safeTransfer(msg.sender, outputTokenAmount);

        updateTokenBalanceAndCheckKValue(poolPos, tokenOut);
    }

    function updateTokenBalanceAndCheckKValue(uint poolPos, address token)
        private
    {
        uint oldKValue = pools[poolPos].balanceToken * pools[poolPos].balanceCerUsd;
        uint112 newBalanceToken = uint112(IERC20(token).balanceOf(address(this)));
        uint newKValue = newBalanceToken * pools[poolPos].balanceCerUsd;
        require(
            newKValue >= oldKValue,
            "CS1: K value decreased"
        );

        // TODO: check if K value can decrease anyhow without using burnHumanAddress cheats

        if (newBalanceToken != pools[poolPos].balanceToken)
        {
            pools[poolPos].balanceToken = newBalanceToken;
        }
    }

    function sync(address token)
        public
        nonReentrant()
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
        returns (uint112)
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
        returns (uint112)
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
        returns (uint112)
    {
        uint amountInWithFee = amountIn * poolFee;
        uint amountOut = 
            (reservesOut * amountInWithFee) / (reservesIn * FEE_DENORM + amountInWithFee);
        return uint112(amountOut);
    }
}