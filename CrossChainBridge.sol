// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./CerbyCronJobsExecution.sol";

struct BulkFeeDependingOnDestinationChainId {
    address token;
    uint256 chainId;
    uint256 amountAsFee;
}

/*

[
    [
        "0xdef1fac7Bf08f173D286BbBDcBeeADe695129840",
        1,
        "100000000000000000000000"
    ],
    [
        "0xdef1fac7Bf08f173D286BbBDcBeeADe695129840",
        56,
        "10000000000000000000000"
    ],
    [
        "0xdef1fac7Bf08f173D286BbBDcBeeADe695129840",
        43114,
        "10000000000000000000000"
    ],
    [
        "0xdef1fac7Bf08f173D286BbBDcBeeADe695129840",
        250,
        "10000000000000000000000"
    ]
]

*/

contract CrossChainBridge is AccessControlEnumerable, CerbyCronJobsExecution {
    event ProofOfBurn(
        address addr,
        address token,
        uint256 amount,
        uint256 amountAsFee,
        uint256 currentNonce,
        uint256 sourceChain,
        uint256 destinationChain,
        bytes32 transactionHash
    );
    event ProofOfMint(
        address addr,
        address token,
        uint256 amountAsFee,
        uint256 finalAmount,
        bytes32 transactionHash
    );
    event ApprovedTransaction(bytes32 transactionHash);
    event BulkApprovedTransactions(bytes32[] transactionHashes);
    event FeeUpdated(uint256 newFeePercent);

    enum States {
        DefaultValue,
        Burned,
        Approved,
        Executed
    }
    mapping(bytes32 => States) public transactionStorage;

    bytes32 public constant ROLE_APPROVER = keccak256("ROLE_APPROVER");

    address UNISWAP_V2_FACTORY_ADDRESS;
    address WETH_TOKEN_ADDRESS;

    mapping(address => uint256) public currentNonce;
    address public beneficiaryAddress;

    mapping(address => mapping(uint256 => uint256)) feeDependingOnDestinationChainId;

    uint256 constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 constant ETH_ROPSTEN_CHAIN_ID = 3;
    uint256 constant ETH_KOVAN_CHAIN_ID = 42;
    uint256 constant BSC_MAINNET_CHAIN_ID = 56;
    uint256 constant BSC_TESTNET_CHAIN_ID = 97;
    uint256 constant MATIC_MAINNET_CHAIN_ID = 137;
    uint256 constant AVALANCHE_MAINNET_CHAIN_ID = 43114;
    uint256 constant FANTOM_MAINNET_CHAIN_ID = 250;

    address constant APPROVER_WALLET =
        0xdEF78a28c78A461598d948bc0c689ce88f812AD8;

    struct SourceProofOfBurn {
        uint256 amountToBridge;
        uint256 amountAsFee;
        uint256 sourceChainId;
        uint256 sourceNonce;
        address sourceTokenAddr;
        bytes32 transactionHash;
    }

    constructor() {
        _setupRole(ROLE_ADMIN, msg.sender);
        _setupRole(ROLE_APPROVER, msg.sender);
        _setupRole(ROLE_APPROVER, APPROVER_WALLET);

        beneficiaryAddress = APPROVER_WALLET;

        BulkFeeDependingOnDestinationChainId[] memory bulkFees;

        /* Testnet */
        /*if (block.chainid == ETH_KOVAN_CHAIN_ID)
        {
            _setupRole(ROLE_ADMIN, 0x539FaA851D86781009EC30dF437D794bCd090c8F);
            _setupRole(ROLE_APPROVER, 0x539FaA851D86781009EC30dF437D794bCd090c8F);
            
            bulkFees = new BulkFeeDependingOnDestinationChainId[](1);
            bulkFees[0] = BulkFeeDependingOnDestinationChainId(0x40A24Fe8E4F7dDd2F614C0BC7e3d405b60f6a248, BSC_TESTNET_CHAIN_ID, 1e5 * 1e18); // allow to bridge to bsc
        } else if (block.chainid == BSC_TESTNET_CHAIN_ID)
        {
            _setupRole(ROLE_ADMIN, 0x539FaA851D86781009EC30dF437D794bCd090c8F);
            _setupRole(ROLE_APPROVER, 0x539FaA851D86781009EC30dF437D794bCd090c8F);
            
            bulkFees = new BulkFeeDependingOnDestinationChainId[](1);
            bulkFees[0] = BulkFeeDependingOnDestinationChainId(0x40A24Fe8E4F7dDd2F614C0BC7e3d405b60f6a248, ETH_KOVAN_CHAIN_ID, 100000 * 1e18); // allow to bridge to eth
        }*/

        /* MAINNET */
        if (block.chainid == ETH_MAINNET_CHAIN_ID) {
            bulkFees = new BulkFeeDependingOnDestinationChainId[](4);
            bulkFees[0] = BulkFeeDependingOnDestinationChainId(
                0xdef1fac7Bf08f173D286BbBDcBeeADe695129840,
                BSC_MAINNET_CHAIN_ID,
                10000 * 1e18
            ); // allow to bridge to bsc
            bulkFees[1] = BulkFeeDependingOnDestinationChainId(
                0xdef1fac7Bf08f173D286BbBDcBeeADe695129840,
                MATIC_MAINNET_CHAIN_ID,
                10000 * 1e18
            ); // allow to bridge to polygon
            bulkFees[2] = BulkFeeDependingOnDestinationChainId(
                0xdef1fac7Bf08f173D286BbBDcBeeADe695129840,
                FANTOM_MAINNET_CHAIN_ID,
                10000 * 1e18
            ); // allow to bridge to fantom
            bulkFees[3] = BulkFeeDependingOnDestinationChainId(
                0xdef1fac7Bf08f173D286BbBDcBeeADe695129840,
                AVALANCHE_MAINNET_CHAIN_ID,
                10000 * 1e18
            ); // allow to bridge to avalanche
        } else if (block.chainid == BSC_MAINNET_CHAIN_ID) {
            bulkFees = new BulkFeeDependingOnDestinationChainId[](4);
            bulkFees[0] = BulkFeeDependingOnDestinationChainId(
                0xdef1fac7Bf08f173D286BbBDcBeeADe695129840,
                ETH_MAINNET_CHAIN_ID,
                100000 * 1e18
            ); // allow to bridge to eth
            bulkFees[1] = BulkFeeDependingOnDestinationChainId(
                0xdef1fac7Bf08f173D286BbBDcBeeADe695129840,
                MATIC_MAINNET_CHAIN_ID,
                10000 * 1e18
            ); // allow to bridge to polygon
            bulkFees[2] = BulkFeeDependingOnDestinationChainId(
                0xdef1fac7Bf08f173D286BbBDcBeeADe695129840,
                FANTOM_MAINNET_CHAIN_ID,
                10000 * 1e18
            ); // allow to bridge to fantom
            bulkFees[3] = BulkFeeDependingOnDestinationChainId(
                0xdef1fac7Bf08f173D286BbBDcBeeADe695129840,
                AVALANCHE_MAINNET_CHAIN_ID,
                10000 * 1e18
            ); // allow to bridge to avalanche
        } else if (block.chainid == MATIC_MAINNET_CHAIN_ID) {
            bulkFees = new BulkFeeDependingOnDestinationChainId[](4);
            bulkFees[0] = BulkFeeDependingOnDestinationChainId(
                0xdef1fac7Bf08f173D286BbBDcBeeADe695129840,
                ETH_MAINNET_CHAIN_ID,
                100000 * 1e18
            ); // allow to bridge to eth
            bulkFees[1] = BulkFeeDependingOnDestinationChainId(
                0xdef1fac7Bf08f173D286BbBDcBeeADe695129840,
                BSC_MAINNET_CHAIN_ID,
                10000 * 1e18
            ); // allow to bridge to bsc
            bulkFees[2] = BulkFeeDependingOnDestinationChainId(
                0xdef1fac7Bf08f173D286BbBDcBeeADe695129840,
                FANTOM_MAINNET_CHAIN_ID,
                10000 * 1e18
            ); // allow to bridge to fantom
            bulkFees[3] = BulkFeeDependingOnDestinationChainId(
                0xdef1fac7Bf08f173D286BbBDcBeeADe695129840,
                AVALANCHE_MAINNET_CHAIN_ID,
                10000 * 1e18
            ); // allow to bridge to avalanche
        } else if (block.chainid == FANTOM_MAINNET_CHAIN_ID) {
            bulkFees = new BulkFeeDependingOnDestinationChainId[](4);
            bulkFees[0] = BulkFeeDependingOnDestinationChainId(
                0xdef1fac7Bf08f173D286BbBDcBeeADe695129840,
                ETH_MAINNET_CHAIN_ID,
                100000 * 1e18
            ); // allow to bridge to eth
            bulkFees[1] = BulkFeeDependingOnDestinationChainId(
                0xdef1fac7Bf08f173D286BbBDcBeeADe695129840,
                BSC_MAINNET_CHAIN_ID,
                10000 * 1e18
            ); // allow to bridge to bsc
            bulkFees[2] = BulkFeeDependingOnDestinationChainId(
                0xdef1fac7Bf08f173D286BbBDcBeeADe695129840,
                MATIC_MAINNET_CHAIN_ID,
                10000 * 1e18
            ); // allow to bridge to polygon
            bulkFees[3] = BulkFeeDependingOnDestinationChainId(
                0xdef1fac7Bf08f173D286BbBDcBeeADe695129840,
                AVALANCHE_MAINNET_CHAIN_ID,
                10000 * 1e18
            ); // allow to bridge to avalanche
        } else if (block.chainid == AVALANCHE_MAINNET_CHAIN_ID) {
            bulkFees = new BulkFeeDependingOnDestinationChainId[](4);
            bulkFees[0] = BulkFeeDependingOnDestinationChainId(
                0xdef1fac7Bf08f173D286BbBDcBeeADe695129840,
                ETH_MAINNET_CHAIN_ID,
                100000 * 1e18
            ); // allow to bridge to eth
            bulkFees[1] = BulkFeeDependingOnDestinationChainId(
                0xdef1fac7Bf08f173D286BbBDcBeeADe695129840,
                BSC_MAINNET_CHAIN_ID,
                10000 * 1e18
            ); // allow to bridge to bsc
            bulkFees[2] = BulkFeeDependingOnDestinationChainId(
                0xdef1fac7Bf08f173D286BbBDcBeeADe695129840,
                FANTOM_MAINNET_CHAIN_ID,
                10000 * 1e18
            ); // allow to bridge to fantom
            bulkFees[3] = BulkFeeDependingOnDestinationChainId(
                0xdef1fac7Bf08f173D286BbBDcBeeADe695129840,
                MATIC_MAINNET_CHAIN_ID,
                10000 * 1e18
            ); // allow to bridge to polygon
        }

        bulkUpdateFeeDependingOnDestinationChainId(bulkFees);
    }

    function getFeeDependingOnDestinationChainId(
        address tokenAddr,
        uint256 destinationChainId
    ) public view returns (uint256) {
        return feeDependingOnDestinationChainId[tokenAddr][destinationChainId];
    }

    function bulkUpdateFeeDependingOnDestinationChainId(
        BulkFeeDependingOnDestinationChainId[] memory bulkFees
    ) public onlyRole(ROLE_ADMIN) {
        for (uint256 i; i < bulkFees.length; i++) {
            feeDependingOnDestinationChainId[bulkFees[i].token][
                bulkFees[i].chainId
            ] = bulkFees[i].amountAsFee;
        }
    }

    function updateBeneficiaryAddress(address newBeneficiaryAddr)
        external
        onlyRole(ROLE_ADMIN)
    {
        beneficiaryAddress = newBeneficiaryAddr;
    }

    function markTransactionAsApproved(bytes32 transactionHash)
        external
        onlyRole(ROLE_APPROVER)
    {
        require(
            transactionStorage[transactionHash] == States.DefaultValue,
            "CCB: Already approved"
        );
        transactionStorage[transactionHash] = States.Approved;
        emit ApprovedTransaction(transactionHash);
    }

    function bulkMarkTransactionsAsApproved(bytes32[] memory transactionHashes)
        external
        onlyRole(ROLE_APPROVER)
    {
        for (uint256 i = 0; i < transactionHashes.length; i++) {
            if (transactionStorage[transactionHashes[i]] < States.Approved) {
                transactionStorage[transactionHashes[i]] = States.Approved;
            } else {
                transactionHashes[i] = 0x0;
            }
        }
        emit BulkApprovedTransactions(transactionHashes);
    }

    function mintWithBurnProof(SourceProofOfBurn memory sourceProofOfBurn)
        external
        checkForBotsAndExecuteCronJobs(msg.sender)
    {
        require(
            transactionStorage[sourceProofOfBurn.transactionHash] ==
                States.Approved,
            "CCB: Transaction is not approved or already executed"
        );
        require(
            sourceProofOfBurn.sourceChainId != block.chainid,
            "CCB: Can't bridge to the same chain"
        );

        bytes32 transactionHash = keccak256(
            abi.encodePacked(
                msg.sender,
                sourceProofOfBurn.sourceTokenAddr,
                sourceProofOfBurn.amountToBridge,
                sourceProofOfBurn.amountAsFee,
                sourceProofOfBurn.sourceChainId,
                block.chainid,
                sourceProofOfBurn.sourceNonce
            )
        );
        require(
            transactionHash == sourceProofOfBurn.transactionHash,
            "CCB: Provided hash is invalid"
        );

        uint256 amountAsFeeHasToBeLargerThanZero = feeDependingOnDestinationChainId[
                sourceProofOfBurn.sourceTokenAddr
            ][sourceProofOfBurn.sourceChainId];
        require(
            amountAsFeeHasToBeLargerThanZero > 0,
            "CCB: Destination is forbidden (mint)"
        );

        transactionStorage[sourceProofOfBurn.transactionHash] = States.Executed;

        uint256 amountAsFee = sourceProofOfBurn.amountAsFee;
        uint256 finalAmount = sourceProofOfBurn.amountToBridge - amountAsFee;

        ICerbyToken(CERBY_TOKEN_CONTRACT_ADDRESS).mintHumanAddress(
            msg.sender,
            finalAmount
        );

        emit ProofOfMint(
            msg.sender,
            sourceProofOfBurn.sourceTokenAddr,
            amountAsFee,
            finalAmount,
            transactionHash
        );
    }

    function burnAndCreateProof(
        address token,
        uint256 amount,
        uint256 destinationChainId
    ) external checkForBotsAndExecuteCronJobs(msg.sender) {
        require(
            amount <=
                ICerbyToken(CERBY_TOKEN_CONTRACT_ADDRESS).balanceOf(msg.sender),
            "CCB: Amount must not exceed available balance. Try reducing the amount."
        );
        require(
            block.chainid != destinationChainId,
            "CCB: Destination chain must be different from current chain"
        );

        uint256 amountAsFee = feeDependingOnDestinationChainId[token][
            destinationChainId
        ];
        require(amountAsFee > 0, "CCB: Destination is forbidden (burn)");
        require(
            amount > amountAsFee,
            "CCB: Amount is lower than the minimum permitted amount"
        );

        bytes32 transactionHash = keccak256(
            abi.encodePacked(
                msg.sender,
                token,
                amount,
                amountAsFee,
                block.chainid,
                destinationChainId,
                currentNonce[token]
            )
        );

        transactionStorage[transactionHash] = States.Burned;

        ICerbyToken(CERBY_TOKEN_CONTRACT_ADDRESS).burnHumanAddress(
            msg.sender,
            amount
        );
        ICerbyToken(CERBY_TOKEN_CONTRACT_ADDRESS).mintHumanAddress(
            beneficiaryAddress,
            amountAsFee
        );

        emit ProofOfBurn(
            msg.sender,
            token,
            amount,
            amountAsFee,
            currentNonce[token],
            block.chainid,
            destinationChainId,
            transactionHash
        );
        currentNonce[token]++;
    }
}
