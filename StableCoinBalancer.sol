// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import "./interfaces/IWeth.sol";
import "./interfaces/ICerbyToken.sol";
import "./interfaces/ICerbySwapLP1155V1.sol";
import "./interfaces/ICerbySwapV1.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./openzeppelin/token/ERC1155/utils/ERC1155Holder.sol";

contract StableCoinBalancer is ERC1155Holder, AccessControlEnumerable {

    address constant usdcToken = 0x7412F2cD820d1E63bd130B0FFEBe44c4E5A47d71; // TODO: update
    address constant cerUsdToken = 0xF690ea79833E2424b05a1d0B779167f5BE763268; // TODO: update
    address constant cerbySwapContract = 0x029581a9121998fcBb096ceafA92E3E10057878f;
    uint constant poolId = 2;
    

    uint constant PRICE_DENORM = 1e18;
    uint constant FEE_DENORM = 10000;

    uint constant PERCENTAGE_INCREASE = 1005;
    uint constant PERCENTAGE_DECREASE = 995;
    uint constant PERCENTAGE_DENORM = 1000;

    uint lastBalancedAt = block.timestamp;
    uint secondsBetweenBalancing = 0;

    uint constant NUMBER_OF_TRADE_PERIODS = 8; 


    constructor() {

        IWeth(usdcToken).approve(cerbySwapContract, type(uint).max);
        IWeth(cerUsdToken).approve(cerbySwapContract, type(uint).max);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155Receiver, AccessControlEnumerable) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
    }

    function addLiquidity()
        public
    {
        uint amountTokensIn = 1e6 * 1e18;
        ICerbyToken(usdcToken).mintHumanAddress(address(this), amountTokensIn);

        ICerbySwapV1(cerbySwapContract).addTokenLiquidity(
            usdcToken, 
            amountTokensIn, 
            block.timestamp + 86400,
            address(this)
        );
    }

    function removeLiquidity(uint percent)
        public
    {
        uint amountLpTokensToBurn = 
            (ICerbySwapLP1155V1(cerbySwapContract).balanceOf(address(this), poolId) * percent) / 
                FEE_DENORM;

        ICerbySwapV1(cerbySwapContract).removeTokenLiquidity(
            usdcToken, 
            amountLpTokensToBurn, 
            block.timestamp + 86400,
            address(this)
        );
    }

    function buyUsdc(uint amountCerUsdIn)
        public
    {
        ICerbyToken(cerUsdToken).mintHumanAddress(address(this), amountCerUsdIn);
        ICerbySwapV1(cerbySwapContract).swapExactTokensForTokens(
            cerUsdToken,
            usdcToken,
            amountCerUsdIn,
            0,
            block.timestamp + 86400,
            address(this)
        );
    }

    function sellUsdc(uint amountUsdcIn)
        public
    {
        ICerbyToken(usdcToken).mintHumanAddress(address(this), amountUsdcIn);
        ICerbySwapV1(cerbySwapContract).swapExactTokensForTokens(
            usdcToken,
            cerUsdToken,
            amountUsdcIn,
            0,
            block.timestamp + 86400,
            address(this)
        );
    }

    function getUsdcPool()
        public
        view
        returns (Pool memory)
    {
        address[] memory tokens = new address[](1);
        tokens[0] = usdcToken;
        return ICerbySwapV1(cerbySwapContract).getPoolsByTokens(tokens)[0];
    }

    function getUsdcPoolValues()
        public
        view
        returns (uint, uint)
    {
        Pool memory pool = getUsdcPool();
        return (pool.balanceToken, pool.balanceCerUsd);
    }

    function calculateK1()
        public
        view
        returns(uint)
    {
        Pool memory pool = getUsdcPool();
        return sqrt(pool.balanceToken * pool.balanceCerUsd);
    }

    function calculateK2()
        public
        view
        returns(uint)
    {
        Pool memory pool = getUsdcPool();
        return sqrt2(pool.balanceToken * pool.balanceCerUsd);
    }

    function balancePrice()
        public
        view
        returns(uint,uint)
    {
        if (
            tx.gasprice > 0 && 
            lastBalancedAt + secondsBetweenBalancing > block.timestamp
        ) {
            return (0,0);
        }

        //lastBalancedAt = block.timestamp;


        uint fee = ICerbySwapV1(cerbySwapContract).getCurrentFeeBasedOnTrades(usdcToken);
        Pool memory pool = getUsdcPool();

        if (pool.balanceToken > pool.balanceCerUsd)
        {
            //return (pool.balanceToken, pool.balanceCerUsd);
            uint sqrtKValue = sqrt(pool.balanceToken * pool.balanceCerUsd / 1e18) * 1e9;
            return (sqrtKValue, pool.balanceCerUsd);
            uint sellCerUSD = ((sqrtKValue - pool.balanceCerUsd) * FEE_DENORM) / fee;

            //buyUsdc(sellCerUSD);
        } else if (pool.balanceToken < pool.balanceCerUsd)
        {
            //removeLiquidity(PERCENTAGE_DENORM - 1);
            
            pool = getUsdcPool();

            uint sqrtKValue = sqrt(pool.balanceToken * pool.balanceCerUsd);
            return (sqrtKValue, pool.balanceToken);
            uint sellUsdcAmount = ((sqrtKValue - pool.balanceToken) * FEE_DENORM) / fee;    
            
            //sellUsdc(sellUsdcAmount);
        }
    }
/*
    function makeCerbyTokensInBothPoolsEqual()
        public
    {
        (, uint balanceCerbyTarget,) = getPriceCerbyUSDC();
        (uint balanceCerUSD, uint balanceCerby,) = getPriceCerbyCerUSD();
        if (balanceCerby * PERCENTAGE_DENORM > balanceCerbyTarget * PERCENTAGE_INCREASE) // >100.5%
        {
            uint difference = balanceCerby - balanceCerbyTarget;
            uint lpSupply = ICerbyToken(uniswapPairCerbyCerUSD).totalSupply();

            uint lpToRemove = (difference * lpSupply) / balanceCerby;
            IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS).removeLiquidity(
                cerUsdToken,
                cerbyToken,
                lpToRemove,
                0,
                0,
                address(this),
                block.timestamp + 86400
            );
        } else if (balanceCerby * PERCENTAGE_DENORM < balanceCerbyTarget * PERCENTAGE_DECREASE) // < 99.5%
        {
            uint difference = balanceCerbyTarget - balanceCerby;
            uint currenctCerbyBalanceAvailable = IWeth(cerbyToken).balanceOf(address(this));
            if (currenctCerbyBalanceAvailable == 0) return;

            difference = difference > currenctCerbyBalanceAvailable? currenctCerbyBalanceAvailable: difference;

            uint cerUsdToMint = (difference * balanceCerUSD) / balanceCerby;
            ICerbyToken(cerUsdToken).mintHumanAddress(address(this), cerUsdToMint);

            IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS).addLiquidity(
                cerUsdToken,
                cerbyToken,
                cerUsdToMint,
                difference,
                0,
                0,
                address(this),
                block.timestamp + 86400
            );
        }
    }

    function removeCerUsdDust()
        public
    {
        uint cerUsdDust = ICerbyToken(cerUsdToken).balanceOf(address(this));
        if (cerUsdDust > 1e16)
        {
            ICerbyToken(cerUsdToken).burnHumanAddress(address(this), cerUsdDust);
        }
    }


    function getPriceCerbyCerUSD()
        public
        view
        returns (uint, uint, uint)
    {
        return getPrice(uniswapPairCerbyCerUSD, cerbyToken, cerUsdToken);
    }    

    function getPriceCerbyUSDC()
        public
        view
        returns (uint, uint, uint)
    {
        return getPrice(uniswapPairCerbyUSDC, cerbyToken, USDCToken);
    }

    function getPrice(address pair, address tokenA, address tokenB)
        private
        view
        returns (uint, uint, uint)
    {
        IUniswapV2Pair iPair = IUniswapV2Pair(pair);
        (uint balanceA, uint balanceB,) = iPair.getReserves();
        if (tokenA > tokenB)
        {
            (balanceA, balanceB) = (balanceB, balanceA);
        }
        uint initialPrice = (balanceB * PRICE_DENORM) / balanceA;
        return (balanceB, balanceA, initialPrice);
    }


    function swapCerbyCerUSD(bool isBuy, uint amountIn)
        public
        returns(uint)
    {
        address[] memory path = new address[](2);
        if (isBuy)
        {
            path[0] = cerUsdToken;
            path[1] = cerbyToken;
        }
        else {        
            path[0] = cerbyToken;
            path[1] = cerUsdToken;
        }
        
        uint[] memory amounts = IUniswapV2Router(UNISWAP_V2_ROUTER_ADDRESS).
            swapExactTokensForTokens(
                amountIn,
                0,
                path,
                address(this),
                block.timestamp + 86400
            );        
        
        return amounts[amounts.length-1];
    }*/

    function withdrawTokens(address[] calldata tokens)
        onlyRole(ROLE_ADMIN)
        public
    {
        uint tokenBalance;
        
        for (uint i; i<tokens.length; i++)
        {
            tokenBalance = IWeth(tokens[i]).balanceOf(address(this));
            if (tokenBalance > 0)
            {
                IWeth(tokens[i]).transfer(msg.sender, tokenBalance);
            }
        }        
    }

    function sqrt(uint y) internal pure returns (uint z) {
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

    function sqrt2(uint x) internal pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}