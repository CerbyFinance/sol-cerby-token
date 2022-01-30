// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.7;

import "./interfaces/IUniswapV2Pair.sol";

interface INoBotsTech {
    function updateSupply(uint256 _realTotalSupply, uint256 _rewardsBalance)
        external;

    function updateTotalSupply(uint256 _realTotalSupply) external;

    function realTotalSupply() external view returns (uint256);

    function cachedMultiplier() external view returns (uint256);

    function balanceOf(address addr) external view returns (uint256);

    function burnHumanAddress(address from, uint256 amount) external;
}

contract NoBotsMigration {
    address owner;

    uint256 constant DENORM = 1e18;
    address constant NO_BOTS_TECH_V2 =
        0x77EC5AF6FE83f90daAEb6F8bd2BE3d744813251b;
    address constant NO_BOTS_TECH_V3 =
        0x1EE133d3CC3fD5795DD4014579A36A6b7900102e;
    address constant DEFT_TOKEN = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840;
    address constant TEAM_VESTING = 0xDEF1fAE3A7713173C168945b8704D4600B6Fc7B9;
    address constant UNISWAP_PAIR = 0xFa6687922BF40FF51Bcd45F9FD339215a4869D82;

    //address constant UNISWAP_PAIR = 0x077324B361272dde2D757f8Ec6Eb59daAe794519;

    constructor() {
        owner = msg.sender;
    }

    function updateSupply() external {
        require(msg.sender == owner, "!owner");

        INoBotsTech noBotsV2 = INoBotsTech(NO_BOTS_TECH_V2);
        INoBotsTech noBotsV3 = INoBotsTech(NO_BOTS_TECH_V3);

        uint256 totalSupply = noBotsV2.realTotalSupply();
        noBotsV2.updateSupply(totalSupply, 0);
        IUniswapV2Pair(UNISWAP_PAIR).sync();

        noBotsV3.updateTotalSupply(totalSupply);
    }

    function burnVesting() external {
        require(msg.sender == owner, "!owner");

        INoBotsTech token = INoBotsTech(DEFT_TOKEN);
        uint256 addrBalance = token.balanceOf(TEAM_VESTING);
        uint256 reducedBalance = (addrBalance * DENORM) / 1494123152996332551;
        token.burnHumanAddress(TEAM_VESTING, addrBalance - reducedBalance);
    }

    /*function burnTokens(address[] memory addrs)
        external
    {
        require(msg.sender == owner, "!owner");
        
        // ETH: 1494123152996332551
        // BSC: 1055206419555273212
        
        INoBotsTech token = INoBotsTech(DEFT_TOKEN);
        for(uint i; i < addrs.length; i++)
        {
            uint addrBalance = token.balanceOf(addrs[i]);
            uint reducedBalance = (addrBalance * 1055206419555273212) / 1494123152996332551;
            token.burnHumanAddress(addrs[i], addrBalance - reducedBalance);
        }
        
        IUniswapV2Pair(UNISWAP_PAIR).sync();
    }*/
}
