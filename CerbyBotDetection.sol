// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.12;

import "../sol-cerby-swap-v1/openzeppelin/access/AccessControlEnumerable.sol";
import "./interfaces/IERC20.sol";

struct CronJob {
    address targetContract;
    bytes4 signature;
}

struct TransactionInfo {
    bool isBuy;
    bool isSell;
}

contract CerbyBotDetection is AccessControlEnumerable {
    CronJob[] public cronJobs;
    mapping(address => bool) private isBotStorage;
    mapping(address => bool) private isHumanStorage;

    mapping(address => uint256) private cooldownPeriodSellStorage;

    mapping(address => mapping(address => uint256))
        private receiveTimestampStorage;

    mapping(address => uint256) private isUniswapPairStorage;

    uint256 constant IS_UNISWAP_PAIR = 1;
    uint256 constant IS_NORMAL_WALLET = 2;
    uint256 constant IS_UNSET_VALUE = 0;

    bytes constant TOKEN0_SIGNATURE = abi.encodeWithSignature("token0()");
    bytes constant TOKEN1_SIGNATURE = abi.encodeWithSignature("token1()");

    address constant EIGHT_LEADING_ZEROS_TO_COMPARE =
        address(0x00000000fFFFffffffFfFfFFffFfFffFFFfFffff);
    address constant STAKING_CONTRACT =
        address(0x8888888AC6aa2482265e5346832CDd963c70A0D1);
    address constant BURN_ADDRESS = address(0);
    uint256 constant DEFAULT_SELL_COOLDOWN = 0 seconds;

    uint256 constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 constant BSC_MAINNET_CHAIN_ID = 56;
    uint256 constant POLYGON_MAINNET_CHAIN_ID = 137;
    uint256 constant AVALANCHE_MAINNET_CHAIN_ID = 43114;
    uint256 constant FANTOM_MAINNET_CHAIN_ID = 250;

    uint256 lastCronJobExecutionBlock = block.number;

    error CerbyBotDetection_TransfersAreTemporarilyDisabled();

    constructor() {
        _setupRole(ROLE_ADMIN, msg.sender);
        _setupRole(ROLE_ADMIN, 0x543a000a9FBE139ff783b2F8EbdF8869452Dc21D); // NoBotsTechV3 Deft

        _setupRole(ROLE_ADMIN, STAKING_CONTRACT); // Staking Contract
        _setupRole(ROLE_ADMIN, 0xEf038429e3BAaF784e1DE93075070df2A43D4278); // Cross Chain Bridge Contract
        _setupRole(ROLE_ADMIN, 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840); // Cerby Token Contract
        _setupRole(ROLE_ADMIN, 0x333333f9E4ba7303f1ac0BF8fE1F47d582629194); // Cerby USD Contract
        _setupRole(ROLE_ADMIN, 0x777777C4e9f6E52bC71e15b7C87a85431D956F2D); // CerbySwapV1 Contract

        markAddressAsBot(0xaeF1352112eE0E98148A10f8e7AAd315c738E98b);
        markAddressAsBot(0x72fe4aB74214f88e48eF39e7B7Fee7a25085e851);
        markAddressAsBot(0xBD50733cE43871F80AdFb344aB6F7C43B666763F);

        markAddressAsHuman(STAKING_CONTRACT, true); // Staking contract
        markAddressAsHuman(0xdEF78a28c78A461598d948bc0c689ce88f812AD8, true); // Cross Chain Bridge Wallet
        markAddressAsHuman(0xDef1C0ded9bec7F1a1670819833240f027b25EfF, true); // 0x: Exchange Proxy
        markAddressAsHuman(0x1111111254fb6c44bAC0beD2854e76F90643097d, true); // 1inch Router
        markAddressAsHuman(0xc590175E458b83680867AFD273527Ff58f74c02b, true); // 1inch Helper1
        markAddressAsHuman(0x3790C9B5A9B9D9AA1c69140a5f01A57c9B868E1e, true); // 1inch Helper2
        markAddressAsHuman(0x2EC255797FEF7669fA243509b7a599121148FFba, true); // 1inch Helper3
        markAddressAsHuman(0x220bdA5c8994804Ac96ebe4DF184d25e5c2196D4, true); // 1inch Helper4
        markAddressAsHuman(0xdef1fac7Bf08f173D286BbBDcBeeADe695129840, true); // CerbyTokenContract
        markAddressAsHuman(0x881D40237659C251811CEC9c364ef91dC08D300C, true); // Metamask Swap Router
        markAddressAsHuman(0x74de5d4FCbf63E00296fd95d33236B9794016631, true); // Metamask Router Wallet
        markAddressAsHuman(0xe122d2E14d35d794C977b4d6924232CAe7c8DbB5, true); // Metamask Fees Wallet

        if (block.chainid == ETH_MAINNET_CHAIN_ID) {
            markAddressAsHuman(
                0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
                true
            ); // uniswap router v2
            markAddressAsHuman(
                0xE592427A0AEce92De3Edee1F18E0157C05861564,
                true
            ); // uniswap router v3
        } else if (block.chainid == BSC_MAINNET_CHAIN_ID) {
            markAddressAsHuman(
                0x10ED43C718714eb63d5aA57B78B54704E256024E,
                true
            ); // pancake router v2
        } else if (block.chainid == POLYGON_MAINNET_CHAIN_ID) {
            markAddressAsHuman(
                0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff,
                true
            ); // quick router v2
        } else if (block.chainid == AVALANCHE_MAINNET_CHAIN_ID) {
            markAddressAsHuman(
                0x60aE616a2155Ee3d9A68541Ba4544862310933d4,
                true
            ); // traderjoe router v2
        } else if (block.chainid == FANTOM_MAINNET_CHAIN_ID) {
            markAddressAsHuman(
                0xF491e7B69E4244ad4002BC14e878a34207E38c29,
                true
            ); // spookyswap router v2
        }

        registerJob(STAKING_CONTRACT, "updateAllSnapshots()");
    }

    function registerJob(
        address _targetContract, 
        string memory _abiCall
    ) 
        public 
    {
        CronJob memory cronJob;
        cronJob.targetContract = _targetContract;
        cronJob.signature = bytes4(abi.encodeWithSignature(_abiCall));

        bool foundGap;
        for (uint256 i; i < cronJobs.length; i++) {
            if (cronJobs[i].targetContract == BURN_ADDRESS) {
                foundGap = true;
                cronJobs[i] = cronJob;
                return;
            }
        }

        if (!foundGap) {
            cronJobs.push(cronJob);
        }
    }

    function removeJobs(address _targetContract) 
        external 
    {
        for (uint256 i; i < cronJobs.length; i++) {
            if (cronJobs[i].targetContract == _targetContract) {
                delete cronJobs[i];
            }
        }
    }

    function getCronJobsLength() 
        external 
        view 
        returns (uint256) 
    {
        return cronJobs.length;
    }

    function executeCronJobs() 
        public 
    {
        if (
            lastCronJobExecutionBlock == block.number &&
            tx.gasprice > 0
        ) {
            return;
        }

        lastCronJobExecutionBlock = block.number;

        CronJob memory cj;
        for (uint256 i; i < cronJobs.length; i++) {
            cj = cronJobs[i];
            if (cj.targetContract != BURN_ADDRESS) {
                address(cj.targetContract).call(
                    abi.encodePacked(cj.signature)
                );
            }
        }

    }

    function getCooldownPeriodSell(address _tokenAddr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint256)
    {
        return
            cooldownPeriodSellStorage[_tokenAddr] > 0
                ? cooldownPeriodSellStorage[_tokenAddr]
                : DEFAULT_SELL_COOLDOWN;
    }

    function updateCooldownPeriodSell(
        address _tokenAddr,
        uint256 _newCooldownSellPeriod
    ) 
        public 
        onlyRole(ROLE_ADMIN) 
    {
        cooldownPeriodSellStorage[_tokenAddr] = _newCooldownSellPeriod;
    }

    function getReceiveTimestamp(
        address _tokenAddr, 
        address _addr
    )
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint256)
    {
        return receiveTimestampStorage[_tokenAddr][_addr];
    }

    function registerTransaction(
        address _tokenAddr, 
        address _addr
    )
        public
        onlyRole(ROLE_ADMIN)
    {
        receiveTimestampStorage[_tokenAddr][_addr] = block.timestamp;
    }

    function detectBotTransaction(
        address _tokenAddr, 
        address _addr
    )
        public
        onlyRole(ROLE_ADMIN)
        returns (bool)
    {
        uint256 defaultSellCooldown = cooldownPeriodSellStorage[_tokenAddr] > 0
            ? cooldownPeriodSellStorage[_tokenAddr]
            : DEFAULT_SELL_COOLDOWN;
        bool isBot = 
            receiveTimestampStorage[_tokenAddr][_addr] + defaultSellCooldown >= block.timestamp ||
            ((isContract(_addr) || isBotStorage[_addr]) &&
                !isHumanStorage[_addr] &&
                !isUniswapPairChecker(_addr, _tokenAddr));
        return isBot;
    }

    function isBotAddress(address _addr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (bool)
    {
        return isBotStorage[_addr] && !isHumanStorage[_addr];
    }

    function checkTransactionInfo( // used in NoBotsTechV3, CerbyToken (avax, fantom) contract
        address _tokenAddr,
        address _sender,
        address _recipient,
        uint256 _recipientBalance, // unused
        uint256 _transferAmount // unused
    ) 
        external 
        onlyRole(ROLE_ADMIN) 
        returns (TransactionInfo memory output) 
    {
        if (
            _sender < EIGHT_LEADING_ZEROS_TO_COMPARE // address starts from 8 zeros
        ) {
            revert CerbyBotDetection_TransfersAreTemporarilyDisabled();
        }

        output.isSell = isUniswapPairChecker(_recipient, _tokenAddr);
        output.isBuy = isUniswapPairChecker(_sender, _tokenAddr);

        uint256 defaultSellCooldown = cooldownPeriodSellStorage[_tokenAddr] > 0
            ? cooldownPeriodSellStorage[_tokenAddr]
            : DEFAULT_SELL_COOLDOWN;
        if (
            output.isBuy && // checking buys
            !output.isSell && // this means exclude when pair sends tokens to other pair => isSell && isBuy
            tx.origin != _recipient && // isOriginBot
            !isContract(_recipient) && // only checking user wallets
            !isHumanStorage[_recipient] && // skipping whitelisted wallets/contracts
            IERC20(_tokenAddr).balanceOf(_recipient) <= 1 // need to make sure balance was zero before the transfer
            // to avoid blacklisting existing users by malicious actors
        ) {
            isBotStorage[_recipient] = true; // allow user to buy but mark as bot
        } else if (
            !isHumanStorage[_sender] && // skipping whitelisted wallets/contracts
            !output.isBuy && // isSell or isTransfer
            (isContract(_sender) || // contracts aren't welcome
                isBotStorage[_sender] || // is Blacklisted Sender
                receiveTimestampStorage[_tokenAddr][_sender] +
                    defaultSellCooldown >=
                block.timestamp)
            // don't allow instant transfer/sell after receiving
        ) {
            revert CerbyBotDetection_TransfersAreTemporarilyDisabled();
        }

        if (
            _sender != STAKING_CONTRACT && // hack to allow scraping stakes
            _recipient != BURN_ADDRESS
        ) {
            /*
            // geometric mean between old and new receive timestamp
            // depending on transferAmount
            receiveTimestampStorage[_tokenAddr][_recipient] =
                (block.timestamp *
                    _transferAmount +
                    receiveTimestampStorage[_tokenAddr][_recipient] *
                    _recipientBalance) /
                (transferAmount + _recipientBalance);*/
            receiveTimestampStorage[_tokenAddr][_recipient] = block.timestamp;
        }

        if (!output.isBuy && !output.isSell) {
            executeCronJobs();
        }

        return output;
    }

    function isUniswapPairChecker(
        address _addr, 
        address _tokenAddr
    )
        private
        returns (bool)
    {
        if (isUniswapPairStorage[_addr] != IS_UNSET_VALUE) {
            return isUniswapPairStorage[_addr] == IS_UNISWAP_PAIR;
        }

        // if (isUniswapPairStorage[_addr] == IS_UNSET_VALUE)
        (, bytes memory token0Bytes) = address(_addr).staticcall(
            TOKEN0_SIGNATURE
        );
        (, bytes memory token1Bytes) = address(_addr).staticcall(
            TOKEN1_SIGNATURE
        );

        address token0 = token0Bytes.length >= 20
            ? abi.decode(token0Bytes, (address))
            : BURN_ADDRESS;
        address token1 = token1Bytes.length >= 20
            ? abi.decode(token1Bytes, (address))
            : BURN_ADDRESS;
        if (
            (token0 == _tokenAddr && token1 != BURN_ADDRESS) ||
            (token0 != BURN_ADDRESS && token1 == _tokenAddr)
        ) {
            isUniswapPairStorage[_addr] = IS_UNISWAP_PAIR;
            return true;
        }

        //if isUniswapPairStorage[_addr] == IS_NORMAL_WALLET
        return false;
    }

    function isContract(address _addr) 
        private 
        view 
        returns (bool) 
    {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

    function isUniswapPair(address _addr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (uint256)
    {
        return isUniswapPairStorage[_addr];
    }

    function isMarkedAsHumanStorage(address _addr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (bool)
    {
        return isHumanStorage[_addr];
    }

    function isMarkedAsHumanStorageBulk(address[] memory _addrs)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (address[] memory)
    {
        for (uint256 i = 0; i < _addrs.length; i++) {
            if (!isHumanStorage[_addrs[i]]) {
                _addrs[i] = BURN_ADDRESS;
            }
        }
        return _addrs;
    }

    function isMarkedAsBotStorage(address _addr)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (bool)
    {
        return isBotStorage[_addr];
    }

    function isMarkedAsBotStorageBulk(address[] memory _addrs)
        external
        view
        onlyRole(ROLE_ADMIN)
        returns (address[] memory)
    {
        for (uint256 i = 0; i < _addrs.length; i++) {
            if (!isBotStorage[_addrs[i]]) {
                _addrs[i] = BURN_ADDRESS;
            }
        }
        return _addrs;
    }

    function markAddressAsHuman(
        address _addr, 
        bool _value
    )
        public
        onlyRole(ROLE_ADMIN)
    {
        isHumanStorage[_addr] = _value;
    }

    function bulkMarkAddressAsHuman(
        address[] calldata _addrs, 
        bool _value
    )
        external
        onlyRole(ROLE_ADMIN)
    {
        for (uint256 i = 0; i < _addrs.length; i++) {
            isHumanStorage[_addrs[i]] = _value;
        }
    }

    function markAsUniswapPair(
        address _addr, 
        uint256 _value
    )
        public
        onlyRole(ROLE_ADMIN)
    {
        isUniswapPairStorage[_addr] = _value;
    }

    function bulkMarkAsUniswapPair(
        address[] calldata _addrs, 
        uint256 _value
    )
        external
        onlyRole(ROLE_ADMIN)
    {
        for (uint256 i = 0; i < _addrs.length; i++) {
            isUniswapPairStorage[_addrs[i]] = _value;
        }
    }

    function markAddressAsBot(address _addr) 
        public 
        onlyRole(ROLE_ADMIN) 
    {
        require(!isBotStorage[_addr], "CBD: bot");

        isBotStorage[_addr] = true;
    }

    function bulkMarkAddressAsBot(address[] calldata _addrs)
        external
        onlyRole(ROLE_ADMIN)
    {
        for (uint256 i = 0; i < _addrs.length; i++) {
            if (!isBotStorage[_addrs[i]]) {
                isBotStorage[_addrs[i]] = true;
            }
        }
    }

    function bulkMarkAddressAsBotBool(
        address[] calldata _addrs, 
        bool _value
    )
        external
        onlyRole(ROLE_ADMIN)
    {
        for (uint256 i = 0; i < _addrs.length; i++) {
            isBotStorage[_addrs[i]] = _value;
        }
    }

    function markAddressAsNotBot(address _addr) 
        external 
        onlyRole(ROLE_ADMIN) 
    {
        require(isBotStorage[_addr], "CBD: !bot");

        isBotStorage[_addr] = false;
    }
}
