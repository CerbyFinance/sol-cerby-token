// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.11;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ICerbyTokenMinterBurner.sol";

struct Pool {
    address token;
    uint112 balanceToken;
    uint112 balanceCerUsd;
    int112 debitCerUsd;
    uint16 fee;
}

contract CerbySwapV1 is AccessControlEnumerable {
    using SafeERC20 for IERC20;

    Pool[] public pools;
    mapping(address => uint) public tokenToPoolPosition;

    address constant testCerbyToken = 0x029581a9121998fcBb096ceafA92E3E10057878f;
    address constant cerUsdContract = 0xA84d62F776606B9eEbd761E2d31F65442eCc437E;
    uint16 constant FEE_DENORM = 10000;
    uint16 constant DEFAULT_FEE = 9985; // 0.15% per transaction XXX <--> cerUSD

    uint public reEntrancyGuardStatus;
    uint constant REENTRANCY_NOT_ENTERED = 1;
    uint constant REENTRANCY_ENTERED = 2;

    constructor() {
        _setupRole(ROLE_ADMIN, msg.sender);
        reEntrancyGuardStatus = REENTRANCY_NOT_ENTERED;

        // Filling with empty pool 0th position
        pools.push(Pool(
            address(0),
            0,
            0,
            0,
            0
        ));

        createPool(
            testCerbyToken,
            1e18 * 1e6,
            1e18 * 3e5,
            DEFAULT_FEE
        );
    }

    modifier reEntrancyProtected()
    {
        require(reEntrancyGuardStatus == REENTRANCY_NOT_ENTERED, "CS1: Reentrant call");

        reEntrancyGuardStatus = REENTRANCY_ENTERED;
        _;
        reEntrancyGuardStatus = REENTRANCY_NOT_ENTERED;
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

    // TODO: add remove pool or disable pool to allow remove liquidity only

    function createPool(address token, uint112 addTokenAmount, uint112 mintCerUsdAmount, uint16 fee)
        public
        reEntrancyProtected()
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
        reEntrancyProtected()
        tokenMustExistInPool(token)
        poolMustBeSynced(token)
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
        reEntrancyProtected()
        tokenMustExistInPool(token)
        poolMustBeSynced(token)
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
    
    // "0x029581a9121998fcBb096ceafA92E3E10057878f", "10000000000000000000000", 0, "2041564156"
    function swapExactTokenToCerUsd(
        address tokenIn,
        uint112 amountTokenIn,
        uint112 minAmountCerUsdOut,
        uint32 expireTimestamp
    )
        public
        reEntrancyProtected()
        transactionIsNotExpired(expireTimestamp)
        tokenMustExistInPool(tokenIn)
        poolMustBeSynced(tokenIn)
        safeTransferTokensNeeded(tokenIn, amountTokenIn)
    {
        uint poolPos = tokenToPoolPosition[tokenIn];
        uint112 increaseTokenBalance = 
            uint112(IERC20(tokenIn).balanceOf(address(this))) - pools[poolPos].balanceToken;

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
        reEntrancyProtected()
        tokenMustExistInPool(tokenOut)
        poolMustBeSynced(tokenOut)
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
        uint oldKValue = uint(pools[poolPos].balanceToken) * uint(pools[poolPos].balanceCerUsd);
        uint112 newBalanceToken = uint112(IERC20(token).balanceOf(address(this)));
        uint newKValue = uint(newBalanceToken) * uint(pools[poolPos].balanceCerUsd);
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

    function adminUpdateFee(address token, uint16 newFee)
        public
        onlyRole(ROLE_ADMIN)
        tokenMustExistInPool(token)
        poolMustBeSynced(token)
    {
        uint poolPos = tokenToPoolPosition[token];
        pools[poolPos].fee = newFee;
    }

    function sync(address token)
        public
    {
        uint poolPos = tokenToPoolPosition[token];
        uint112 newBalanceToken = uint112(IERC20(token).balanceOf(address(this)));
        if (newBalanceToken != pools[poolPos].balanceToken)
        {
            pools[poolPos].balanceToken = newBalanceToken;
        }        
    }

    function getOutputExactTokensForCerUsd(uint poolPos, uint112 increaseTokenBalance)
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

    function getOutputExactCerUsdForToken(uint poolPos, uint112 increaseCerUsdBalance)
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

    function _getOutput(uint112 amountIn, uint112 reservesIn, uint112 reservesOut, uint16 poolFee)
        private
        pure
        returns (uint112)
    {
        uint amountInWithFee = amountIn * poolFee;
        uint amountOut = 
            (reservesOut * amountInWithFee) / (reservesIn * FEE_DENORM + amountInWithFee);
        return uint112(amountOut);
    }

    function testGetPrice()
        public
        view
        returns (uint)
    {
        uint poolPos = tokenToPoolPosition[testCerbyToken];
        return (pools[poolPos].balanceCerUsd * 1e18) / pools[poolPos].balanceToken;
    }
    
}