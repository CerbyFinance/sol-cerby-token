// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.10;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ICerbyTokenMinterBurner.sol";

struct Pool {
    address token;
    uint balanceToken;
    uint balanceCerUsd;
    uint debitCerUsd;
    uint creditCerUsd;
    uint fee;
}

contract CerbySwapV1 is AccessControlEnumerable {
    using SafeERC20 for IERC20;

    Pool[] public pools;
    mapping(address => uint) public tokenToPoolPosition;

    address constant cerUsdContract = 0x3B69b8C5c6a4c8c2a90dc93F3B0238BF70cC9640;
    uint constant FEE_DENORM = 10000;

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
            9970
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

    function adminUpdateFee(address token, uint newFee)
        public
        onlyRole(ROLE_ADMIN)
        tokenMustExistInPool(token)
    {
        uint poolPos = tokenToPoolPosition[token];
        pools[poolPos].fee = newFee;
    }

    function createPool(address token, uint addTokenAmount, uint mintCerUsdAmount, uint fee)
        public
        tokenDoesNotExistInPool(token)
        safeTransferTokensNeeded(token, addTokenAmount)
    {
        require(
            fee == 9970, // TODO: add other values
            "CS1: Incorrect fee provided"
        );

        ICerbyTokenMinterBurner(cerUsdContract).mintHumanAddress(address(this), mintCerUsdAmount);

        // Admins can create official pools with no limit on selling
        // Users can create regular pools where they can't sell more than bought
        uint newCerUsdDebit = hasRole(ROLE_ADMIN, msg.sender)? mintCerUsdAmount: 0;
        pools.push(
            Pool(
                token,
                addTokenAmount,
                mintCerUsdAmount,
                newCerUsdDebit,
                0,
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

    function removeTokenLiquidity(address token, uint addTokenAmount)
        public
        tokenMustExistInPool(token)
    {
        // TODO: burn LP tokens
        // TODO: if debit > credit return cerUSD additionally
        // TODO: if debit < credit return reduced tokenAmount

        updateTokenBalanceAndCheckKValue(tokenToPoolPosition[token], token);
    }

    // TODO: add swapTokenToExactCerUSD XXX --> cerUSD
    // TODO: add swapCerUsdToExactToken cerUSD --> YYY
    // TODO: add swapExactTokenToToken XXX --> cerUSD --> YYY (XXX != YYY)
    // TODO: add swapTokenToExactToken XXX --> cerUSD --> YYY (XXX != YYY)
    
    function swapExactTokenToCerUsd(
        address tokenIn,
        uint amountTokenIn,
        uint minAmountCerUsdOut,
        uint expireTimestamp
    )
        public
        tokenMustExistInPool(tokenIn)
        transactionIsNotExpired(expireTimestamp)
        safeTransferTokensNeeded(tokenIn, amountTokenIn)
    {
        uint poolPos = tokenToPoolPosition[tokenIn];
        uint increaseTokenBalance = 
            IERC20(tokenIn).balanceOf(address(this)) - pools[poolPos].balanceToken;

        uint outputCerUsdAmount = getOutputCerUsd(poolPos, increaseTokenBalance);
        require(
            outputCerUsdAmount >= minAmountCerUsdOut,
            "CS1: Output amount less than minimum specified"
        );

        require(
            // For user-created pools you can't sell more than bought
            // For official pools - no limits
            pools[poolPos].creditCerUsd + outputCerUsdAmount <= pools[poolPos].debitCerUsd,
            "CS1: Can't sell more than bought"
        );

        pools[poolPos].creditCerUsd += outputCerUsdAmount;
        pools[poolPos].balanceCerUsd -= outputCerUsdAmount;
        pools[poolPos].balanceToken += amountTokenIn;

        IERC20(cerUsdContract).transfer(msg.sender, outputCerUsdAmount);

        updateTokenBalanceAndCheckKValue(poolPos, tokenIn);
    }

    function updateTokenBalanceAndCheckKValue(uint poolPos, address token)
        public
        tokenMustExistInPool(token)
    {
        uint newBalanceToken = IERC20(token).balanceOf(address(this));
        uint oldKValue = pools[poolPos].balanceToken * pools[poolPos].balanceCerUsd;
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

    function swapExactCerUsdToToken(
        address tokenOut,
        uint amountCerUsdIn,
        uint minAmountTokenOut,
        uint expireTimestamp
    )
        public
        tokenMustExistInPool(tokenOut)
        transactionIsNotExpired(expireTimestamp)
        safeTransferTokensNeeded(cerUsdContract, amountCerUsdIn)
    {
        uint poolPos = tokenToPoolPosition[tokenOut];
        uint increaseCerUsdBalance = 
            IERC20(cerUsdContract).balanceOf(address(this)) - pools[poolPos].balanceCerUsd;

        uint outputTokenAmount = getOutputToken(poolPos, increaseCerUsdBalance);
        require(
            outputTokenAmount >= minAmountTokenOut,
            "CS1: Output amount less than minimum specified"
        );

        pools[poolPos].debitCerUsd += increaseCerUsdBalance;
        pools[poolPos].balanceCerUsd += increaseCerUsdBalance;
        pools[poolPos].balanceToken -= outputTokenAmount;

        IERC20(tokenOut).safeTransfer(msg.sender, outputTokenAmount);
    }

    function getOutputCerUsd(uint poolPos, uint deltaTokenBalance)
        public
        view
        returns (uint)
    {
        return _getOutput(
            deltaTokenBalance,
            pools[poolPos].balanceToken,
            pools[poolPos].balanceCerUsd,
            pools[poolPos].fee
        );
    }

    function getOutputToken(uint poolPos, uint deltaCerUsdBalance)
        public
        view
        returns (uint)
    {
        return _getOutput(
            deltaCerUsdBalance,
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
            (reservesOut * amountInWithFee) / (reservesIn * FEE_DENORM + amountInWithFee);
        return amountOut;
    }
}