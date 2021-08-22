// SPDX-License-Identifier: BSD-2-Clause

pragma solidity ^0.8.7;

contract PresaleFactory {
    
    struct PresaleListItem {
        address presaleContractAddress;
        string presaleName;
        uint totalInvestedWeth;
        uint maxWethCap;
        bool isCompleted;
        bool isEnabled;
        string website;
        string telegram;
    }
    
    struct WalletInfoItem {
        address walletAddress;
        uint walletInvestedWeth;
        uint walletReferralEarnings;
        uint minimumWethPerWallet;
        uint maximumWethPerWallet;
    }

    struct TokenomicsItem {
        address tokenomicsAddr;
        string tokenomicsName;
        uint tokenomicsPercentage;
        uint tokenomicsLockedForXSeconds;
        uint tokenomicsVestedForXSeconds;
    }
    
    struct VestingItem {
        address vestingAddr;
        uint tokensReserved;
        uint tokensClaimed;
        uint lockedUntilTimestamp;
        uint vestedUntilTimestamp;
    }
    
    struct OutputItem {
        PresaleListItem presaleItem;
        WalletInfoItem walletInfo;
        VestingItem vestingInfo;
        TokenomicsItem[] tokenomics;
        uint listingPrice;
        uint createdAt;
    }
    
    
    function listPresales(address walletAddress, uint page, uint limit)
        public
        view
        returns (OutputItem[] memory)
    {
        TokenomicsItem[] memory tokenomics1 = new TokenomicsItem[](2);
        tokenomics1[0] = TokenomicsItem(
            0x123f75Cf0F6A97023D957ba98E2Df17aB3143CE7,
            "Liquidity",
            15e4,
            36500 days,
            0 days
        );
        tokenomics1[1] = TokenomicsItem(
            0x123f75Cf0F6A97023D957ba98E2Df17aB3143CE7,
            "Token Sale",
            85e4,
            1 days,
            7 days
        );
        
        TokenomicsItem[] memory tokenomics2 = new TokenomicsItem[](3);
        tokenomics2[0] = TokenomicsItem(
            0x987F75cf0F6a97023d957Ba98E2df17AB3143cE7,
            "Liquidity",
            90e4,
            365 days,
            0 days
        );
        tokenomics2[1] = TokenomicsItem(
            0x789F75cf0F6a97023D957Ba98E2df17AB3143ce7,
            "Token Sale",
            5e4,
            7 days,
            14 days
        );
        tokenomics2[2] = TokenomicsItem(
            0x777f75cF0F6a97023d957bA98E2Df17aB3143Ce7,
            "Developer",
            5e4,
            365 days,
            730 days
        );
        
        OutputItem[] memory output = new OutputItem[](2);
        output[0] = OutputItem(
            PresaleListItem(
               0x132209d0F93eBFF185990D768126D32621F40c43,
               "Lambo presale",
               200e18,
               200e18,
               false,
               true,
               "https://lambo.defifactory.finance",
               "https://t.me/LamboTokenOwners"
            ),
            WalletInfoItem(
                walletAddress,
                12e18,
                1e18,
                1e18,
                200e18
            ),
            VestingItem(
                walletAddress,
                125e18,
                25e18,
                block.timestamp + 1 days,
                block.timestamp + 1 days + 365 days
            ),
            tokenomics1,
            123e13,
            block.timestamp
        );
        output[1] = OutputItem(
            PresaleListItem(
               0x132209d0F93eBFF185990D768126D32621F40c43,
               "Deft presale",
               12e18,
               20e18,
               true,
               true,
               "https://defifactory.finance",
               "https://t.me/DefiFactory"
            ),
            WalletInfoItem(
                walletAddress,
                1e18,
                1e17,
                1e17,
                10e18
            ),
            VestingItem(
                walletAddress,
                125e18,
                25e18,
                block.timestamp + 48 days,
                block.timestamp + 48 days + 365 days
            ),
            tokenomics2,
            987e17,
            block.timestamp
        );
        
        return output;
    }
}