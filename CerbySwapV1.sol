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
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        _;
    }

    function createPool(address token, uint addTokenAmount, uint mintCerUsdAmount, uint fee)
        public
        tokenDoesNotExistInPool(token)
        safeTransferTokensNeeded(token, addTokenAmount)
    {
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
        tokenToPoolPosition[token] = pools.length;

        // TODO: mint LP tokens
    }


    function addTokenLiquidity(address token, uint addTokenAmount)
        public
        tokenMustExistInPool(token)
        safeTransferTokensNeeded(token, addTokenAmount)
    {
        uint poolPos = getPoolPositionByToken(token);
        uint mintCerUsdAmount = 
            (addTokenAmount * pools[poolPos].balanceCerUsd) / pools[poolPos].balanceToken;
        ICerbyTokenMinterBurner(cerUsdContract).mintHumanAddress(address(this), mintCerUsdAmount);

        pools[poolPos].balanceToken += addTokenAmount;
        pools[poolPos].balanceCerUsd += mintCerUsdAmount;

        // TODO: mint LP tokens
    }
    function removeTokenLiquidity(address token, uint addTokenAmount)
        public
        tokenMustExistInPool(token)
    {
        // TODO: burn LP tokens
        // TODO: if debit > credit return cerUSD additionally
        // TODO: if debit < credit return reduced tokenAmount
    }

    // TODO: add swapTokenToExactCerUSD XXX --> cerUSD
    // TODO: add swapCerUsdToExactToken cerUSD --> YYY
    // TODO: add swapExactTokenToToken XXX --> cerUSD --> YYY
    // TODO: add swapTokenToExactToken XXX --> cerUSD --> YYY
    
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
        uint poolPos = getPoolPositionByToken(tokenIn);
        uint increaseTokenBalance = 
            IERC20(tokenIn).balanceOf(address(this)) - pools[poolPos].balanceToken;

        uint outputCerUsd = getOutputCerUsd(poolPos, increaseTokenBalance);
        require(
            outputCerUsd >= minAmountCerUsdOut,
            "CS1: Output amount less than minimum specified"
        );

        require(
            // For user-created pools you can't sell more than bought
            // For official pools - no limits
            pools[poolPos].creditCerUsd + outputCerUsd <= pools[poolPos].debitCerUsd,
            "CS1: Can't sell more than bought"
        );

        pools[poolPos].creditCerUsd += outputCerUsd;
        IERC20(cerUsdContract).transfer(msg.sender, outputCerUsd);

        updateBalancesAndCheckKValue(poolPos, tokenIn);
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
        uint poolPos = getPoolPositionByToken(tokenOut);
        uint increaseCerUsdBalance = 
            IERC20(cerUsdContract).balanceOf(address(this)) - pools[poolPos].balanceCerUsd;

        uint outputToken = getOutputToken(poolPos, increaseCerUsdBalance);
        require(
            outputToken >= minAmountTokenOut,
            "CS1: Output amount less than minimum specified"
        );

        pools[poolPos].debitCerUsd += increaseCerUsdBalance;
        IERC20(tokenOut).safeTransfer(msg.sender, outputToken);

        updateBalancesAndCheckKValue(poolPos, tokenOut);
    }

    function updateBalancesAndCheckKValue(uint poolPos, address token)
        private
    {
        uint previousPoolKValue = pools[poolPos].balanceToken * pools[poolPos].balanceCerUsd;

        updateBalances(poolPos, token);

        uint newPoolKValue = pools[poolPos].balanceToken * pools[poolPos].balanceCerUsd;
        require(
            newPoolKValue >= previousPoolKValue,
            "CS1: K value decreased"
        );
    }

    function updateBalances(uint poolPos, address token)
        public
    {
        uint newBalanceToken = IERC20(token).balanceOf(address(this));
        uint newBalanceCerUsd = IERC20(cerUsdContract).balanceOf(address(this));
        pools[poolPos].balanceToken = newBalanceToken;
        pools[poolPos].balanceCerUsd = newBalanceCerUsd;
    }

    function getPoolPositionByToken(address token)
        public
        view
        returns (uint)
    {
        return tokenToPoolPosition[token] - 1;
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