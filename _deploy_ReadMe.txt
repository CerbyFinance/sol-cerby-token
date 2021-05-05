Deploy process:
1) deploy DefiFactoryToken
2) deploy NoBotTech
3) deploy TeamVestingContract
4) call DefiFactoryToken.updateUtilsContracts
/*
    0 - NoBotsTech
    1 - TeamVestingContract
    2 - Uniswap V2 Factory
    
    [
        [false, false, false, false, false, "0x5aA83AD2D0eaa497271122e22EeF5dE3f825Be5f"],
        [true, true, true, true, true, "0xafB09ACdd26Cbe9cb53baB234B534D48c8d55457"],
        [false, false, false, false, false, "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"]
    ]
*/
5) NoBotTech.grantRoles( // 
    DefiFactoryToken ROLE_PARENT
    TeamVestingContract ROLE_ADMIN
    TeamVestingContract ROLE_WHITELIST
    TeamVestingContract ROLE_EXCLUDE_FROM_BALANCE

    [
        ["0xc869e1d528fd91a06036810c7f025f082e044b8f0374c3d1d4b1fb5490dd90ae", "0x2cfC5195E21Fecb72103ECea7AB01E7B2a5D026B"],
        ["0x0000000000000000000000000000000000000000000000000000000000000000", "0xafB09ACdd26Cbe9cb53baB234B534D48c8d55457"],
        ["0xd27488087fca693adcf8b477ec0ca6cf5134d7f124fdc511eb258522c40fd72b", "0xafB09ACdd26Cbe9cb53baB234B534D48c8d55457"],
        ["0x2eb7a2681a755a3da9e842879bcbcac38d32d4567f8f95e32a00f74605b40993", "0xafB09ACdd26Cbe9cb53baB234B534D48c8d55457"]
    ]
)
6) TeamVestingContract.updateDefiFactoryToken(0x2cfC5195E21Fecb72103ECea7AB01E7B2a5D026B)
7) TeamVestingContract.
    updateInvestmentSettings(
        0xd0A1E359811322d97991E03f863a0C30C2cF029C, // Native token: WETH kovan
        0x539FaA851D86781009EC30dF437D794bCd090c8F, 150e13, // dev address & cap
        0xDc15Ca882F975c33D8f20AB3669D27195B8D87a6, 100e13, // team address & cap
        0xE019B37896f129354cf0b8f1Cf33936b86913A34, 50e13 // marketing address & cap
    );