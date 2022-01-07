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
    Pool[] pools;
    using SafeERC20 for IERC20;

    mapping(address => uint) tokenToPoolPosition;

    address constant cerUsdContract = 0x3B69b8C5c6a4c8c2a90dc93F3B0238BF70cC9640;
    uint constant FEE_DENORM = 10000;

    constructor() {
        _setupRole(ROLE_ADMIN, msg.sender);

        address cerbyToken = 0xE7126C0Fb4B1f5F79E5Bbec3948139dCF348B49C;
        adminCreatePool(
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

    function adminCreatePool(address token, uint addTokenAmount, uint mintCerUsdAmount, uint fee)
        public
        tokenDoesNotExistInPool(token)
        onlyRole(ROLE_ADMIN)
    {
        IERC20(token).safeTransferFrom(msg.sender, address(this), addTokenAmount);        
        ICerbyTokenMinterBurner(cerUsdContract).mintHumanAddress(address(this), mintCerUsdAmount);

        pools.push(
            Pool(
                token,
                addTokenAmount,
                mintCerUsdAmount,
                0,
                0,
                fee
            )
        );
        tokenToPoolPosition[token] = pools.length;
    }

    function swapExactTokenToCerUsd(
        address tokenIn,
        uint amountTokenIn,
        uint minAmountCerUsdOut,
        uint expireTimestamp
    )
        public
        tokenMustExistInPool(tokenIn)
        transactionIsNotExpired(expireTimestamp)
    {
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountTokenIn);

        uint poolPos = getPoolPositionByToken(tokenIn);
        uint deltaTokenBalance = 
            IERC20(tokenIn).balanceOf(address(this)) - pools[poolPos].balanceToken;

        uint outputCerUsd = getOutputCerUsd(poolPos, deltaTokenBalance);
        require(
            outputCerUsd >= minAmountCerUsdOut,
            "CS1: Output amount less than minimum specified"
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
    {
        IERC20(cerUsdContract).transferFrom(msg.sender, address(this), amountCerUsdIn);

        uint poolPos = getPoolPositionByToken(tokenOut);
        uint deltaCerUsdBalance = 
            IERC20(cerUsdContract).balanceOf(address(this)) - pools[poolPos].balanceCerUsd;

        uint outputToken = getOutputToken(poolPos, deltaCerUsdBalance);
        require(
            outputToken >= minAmountTokenOut,
            "CS1: Output amount less than minimum specified"
        );

        pools[poolPos].debitCerUsd += deltaCerUsdBalance;
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