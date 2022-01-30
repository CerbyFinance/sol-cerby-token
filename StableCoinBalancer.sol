// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.11;

import "./interfaces/IWeth.sol";
import "./interfaces/ICerbyToken.sol";
import "./interfaces/ICerbySwapLP1155V1.sol";
import "./interfaces/ICerbySwapV1.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./openzeppelin/token/ERC1155/utils/ERC1155Holder.sol";

contract StableCoinBalancer is ERC1155Holder, AccessControlEnumerable {
    address constant usdcToken = 0x7412F2cD820d1E63bd130B0FFEBe44c4E5A47d71; // TODO: update
    address constant cerUsdToken = 0xF690ea79833E2424b05a1d0B779167f5BE763268; // TODO: update
    address constant cerbySwapContract =
        0xD90AFC36ffE32deb42562A7E829A4a592589E677;
    uint256 constant poolId = 2;

    uint256 constant PRICE_DENORM = 1e18;
    uint256 constant FEE_DENORM = 10000;

    uint256 constant PERCENTAGE_INCREASE = 10100;
    uint256 constant PERCENTAGE_DECREASE = 9900;
    uint256 constant PERCENTAGE_DENORM = 10000;

    uint256 lastBalancedAt = block.timestamp;
    uint256 secondsBetweenBalancing = 0;

    uint256 constant NUMBER_OF_TRADE_PERIODS = 8;

    constructor() {
        IWeth(usdcToken).approve(cerbySwapContract, type(uint256).max);
        IWeth(cerUsdToken).approve(cerbySwapContract, type(uint256).max);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Receiver, AccessControlEnumerable)
        returns (bool)
    {
        return
            interfaceId == type(IERC1155Receiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function addLiquidity(uint256 amountUsdcIn, bool isMint)
        public
        returns (uint256)
    {
        if (isMint) {
            ICerbyToken(usdcToken).mintHumanAddress(
                address(this),
                amountUsdcIn
            );
        }

        return
            ICerbySwapV1(cerbySwapContract).addTokenLiquidity(
                usdcToken,
                amountUsdcIn,
                block.timestamp + 86400,
                address(this)
            );
    }

    function removeLiquidity(uint256 percent) public returns (uint256) {
        uint256 amountLpTokensToBurn = (ICerbySwapLP1155V1(cerbySwapContract)
            .balanceOf(address(this), poolId) * percent) / FEE_DENORM;

        return
            ICerbySwapV1(cerbySwapContract).removeTokenLiquidity(
                usdcToken,
                amountLpTokensToBurn,
                block.timestamp + 86400,
                address(this)
            );
    }

    function buyUsdc(uint256 amountCerUsdIn) public returns (uint256, uint256) {
        ICerbyToken(cerUsdToken).mintHumanAddress(
            address(this),
            amountCerUsdIn
        );
        return
            ICerbySwapV1(cerbySwapContract).swapExactTokensForTokens(
                cerUsdToken,
                usdcToken,
                amountCerUsdIn,
                0,
                block.timestamp + 8640000,
                address(this)
            );
    }

    function sellUsdc(uint256 amountUsdcIn, bool isMint)
        public
        returns (uint256, uint256)
    {
        if (isMint) {
            ICerbyToken(usdcToken).mintHumanAddress(
                address(this),
                amountUsdcIn
            );
        }
        return
            ICerbySwapV1(cerbySwapContract).swapExactTokensForTokens(
                usdcToken,
                cerUsdToken,
                amountUsdcIn,
                0,
                block.timestamp + 8640000,
                address(this)
            );
    }

    function getUsdcPool() public view returns (uint256, uint256) {
        address[] memory tokens = new address[](1);
        tokens[0] = usdcToken;
        Pool memory pool = ICerbySwapV1(cerbySwapContract).getPoolsByTokens(
            tokens
        )[0];
        return (uint256(pool.balanceToken), uint256(pool.balanceCerUsd));
    }

    function balancePrice() public {
        if (
            tx.gasprice > 0 &&
            lastBalancedAt + secondsBetweenBalancing > block.timestamp
        ) {
            return;
        }

        lastBalancedAt = block.timestamp;

        (uint256 balanceUsdc, uint256 balanceCerUsd) = getUsdcPool();

        if (
            balanceUsdc * PERCENTAGE_DECREASE >
            balanceCerUsd * PERCENTAGE_DENORM
        ) {
            uint256 fee = FEE_DENORM; // fee is zero for swaps cerUsd --> Any

            uint256 B = (balanceCerUsd * (FEE_DENORM + fee)) / (2 * fee);
            uint256 C = ((balanceUsdc *
                balanceCerUsd -
                balanceCerUsd *
                balanceCerUsd) * FEE_DENORM) / fee;
            uint256 amountCerUsdIn = sqrt(B * B + C) - B;

            (, uint256 amountUsdcOut) = buyUsdc(amountCerUsdIn);

            addLiquidity(amountUsdcOut, false);
        } else if (
            balanceUsdc * PERCENTAGE_INCREASE <
            balanceCerUsd * PERCENTAGE_DENORM
        ) {
            uint256 fee = ICerbySwapV1(cerbySwapContract)
                .getCurrentFeeBasedOnTrades(usdcToken);
            uint256 amountUsdcMax = removeLiquidity(PERCENTAGE_DENORM - 1);

            (balanceUsdc, balanceCerUsd) = getUsdcPool();
            uint256 B = (balanceUsdc * (FEE_DENORM + fee)) / (2 * fee);
            uint256 C = ((balanceUsdc *
                balanceCerUsd -
                balanceUsdc *
                balanceUsdc) * FEE_DENORM) / fee;
            uint256 amountUsdcIn = sqrt(B * B + C) - B;
            amountUsdcIn = amountUsdcIn < amountUsdcMax
                ? amountUsdcIn
                : amountUsdcMax;

            (, uint256 amountCerUsdOut) = sellUsdc(amountUsdcIn, false);
            ICerbyToken(cerUsdToken).burnHumanAddress(
                address(this),
                amountCerUsdOut
            );

            uint256 amountUsdcDiff = amountUsdcMax - amountUsdcIn;
            if (amountUsdcDiff > 0) {
                addLiquidity(amountUsdcDiff, false);
            }
        }
    }

    function withdrawTokens(address[] calldata tokens)
        public
        onlyRole(ROLE_ADMIN)
    {
        uint256 tokenBalance;

        for (uint256 i; i < tokens.length; i++) {
            tokenBalance = IWeth(tokens[i]).balanceOf(address(this));
            if (tokenBalance > 0) {
                IWeth(tokens[i]).transfer(msg.sender, tokenBalance);
            }
        }
    }

    function withdrawLP(uint256 _poolId) public onlyRole(ROLE_ADMIN) {
        uint256 lpBalance = ICerbySwapLP1155V1(cerbySwapContract).balanceOf(
            address(this),
            _poolId
        );

        ICerbySwapLP1155V1(cerbySwapContract).safeTransferFrom(
            address(this),
            msg.sender,
            _poolId,
            lpBalance,
            ""
        );
    }

    function sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
