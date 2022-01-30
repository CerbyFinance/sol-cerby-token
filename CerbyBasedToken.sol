// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.11;

import "./interfaces/ICerbyToken.sol";
import "./interfaces/ICerbyBotDetection.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./openzeppelin/token/ERC20/extensions/draft-ERC20Permit.sol";
import "./CerbyCronJobsExecution.sol";

contract CerbyBasedToken is
    Context,
    AccessControlEnumerable,
    ERC20,
    ERC20Permit,
    CerbyCronJobsExecution
{
    bytes32 public constant ROLE_MINTER = keccak256("ROLE_MINTER");
    bytes32 public constant ROLE_BURNER = keccak256("ROLE_BURNER");
    bytes32 public constant ROLE_TRANSFERER = keccak256("ROLE_TRANSFERER");
    bytes32 public constant ROLE_MODERATOR = keccak256("ROLE_MODERATOR");

    address constant BURN_ADDRESS = address(0x0);

    bool public isPaused;
    bool isInitialized;

    event TransferCustom(address sender, address recipient, uint256 amount);
    event MintHumanAddress(address recipient, uint256 amount);
    event BurnHumanAddress(address sender, uint256 amount);

    error CerbyBasedToken_AlreadyInitialized();
    error CerbyBasedToken_ContractIsPaused();
    error CerbyBasedToken_ContractIsNotPaused();
    error CerbyBasedToken_RecipientIsBurnAddress();
    error CerbyBasedToken_DecreasedAllowanceBelowZero();
    error CerbyBasedToken_TransferAmountExceedsAllowance();
    error CerbyBasedToken_TransferAmountExceedsBalance();

    constructor(string memory name, string memory symbol)
        ERC20(name, symbol)
        ERC20Permit(name)
    {}

    function initializeOwner(address owner) internal {
        if (isInitialized) {
            revert CerbyBasedToken_AlreadyInitialized();
        }

        isInitialized = true;
        _setupRole(ROLE_ADMIN, owner);
        _setupRole(ROLE_MINTER, owner);
        _setupRole(ROLE_BURNER, owner);
        _setupRole(ROLE_TRANSFERER, owner);
        _setupRole(ROLE_MODERATOR, owner);
    }

    modifier checkTransaction(
        address sender,
        address recipient,
        uint256 transferAmount
    ) {
        ICerbyBotDetection iCerbyBotDetection = ICerbyBotDetection(
            getUtilsContractAtPos(CERBY_BOT_DETECTION_CONTRACT_ID)
        );
        iCerbyBotDetection.checkTransactionInfo(
            CERBY_TOKEN_CONTRACT_ADDRESS,
            sender,
            recipient,
            _balances[recipient],
            transferAmount
        );
        _;
    }

    modifier notPausedContract() {
        if (isPaused) {
            revert CerbyBasedToken_ContractIsPaused();
        }
        _;
    }

    modifier pausedContract() {
        if (!isPaused) {
            revert CerbyBasedToken_ContractIsNotPaused();
        }
        _;
    }

    modifier recipientIsNotBurnAddress(address recipient) {
        if (recipient == BURN_ADDRESS) {
            revert CerbyBasedToken_RecipientIsBurnAddress();
        }

        _;
    }

    function updateNameAndSymbol(
        string calldata __name,
        string calldata __symbol
    ) external onlyRole(ROLE_ADMIN) {
        _name = __name;
        _symbol = __symbol;
    }

    function pauseContract() external notPausedContract onlyRole(ROLE_ADMIN) {
        isPaused = true;
    }

    function resumeContract() external pausedContract onlyRole(ROLE_ADMIN) {
        isPaused = false;
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        notPausedContract
        checkForBotsAndExecuteCronJobs(msg.sender)
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        override
        notPausedContract
        checkForBotsAndExecuteCronJobs(msg.sender)
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        override
        notPausedContract
        checkForBotsAndExecuteCronJobs(msg.sender)
        returns (bool)
    {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        if (currentAllowance < subtractedValue) {
            revert CerbyBasedToken_DecreasedAllowanceBelowZero();
        }

        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        notPausedContract
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    )
        public
        virtual
        override
        notPausedContract
        recipientIsNotBurnAddress(recipient)
        returns (bool)
    {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        if (currentAllowance < amount) {
            revert CerbyBasedToken_TransferAmountExceedsAllowance();
        }
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function moderatorTransferFromWhilePaused(
        address sender,
        address recipient,
        uint256 amount
    )
        external
        pausedContract
        onlyRole(ROLE_MODERATOR)
        recipientIsNotBurnAddress(recipient)
        returns (bool)
    {
        _transfer(sender, recipient, amount);

        return true;
    }

    function transferCustom(
        address sender,
        address recipient,
        uint256 amount
    )
        external
        notPausedContract
        onlyRole(ROLE_TRANSFERER)
        recipientIsNotBurnAddress(recipient)
    {
        _transfer(sender, recipient, amount);

        emit TransferCustom(sender, recipient, amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 transferAmount
    )
        internal
        virtual
        override
        recipientIsNotBurnAddress(recipient)
        checkTransaction(sender, recipient, transferAmount)
    {
        uint256 senderBalance = _balances[sender];
        if (senderBalance < transferAmount) {
            revert CerbyBasedToken_TransferAmountExceedsBalance();
        }
        unchecked {
            _balances[sender] = senderBalance - transferAmount;
        }
        _balances[recipient] += transferAmount;

        emit Transfer(sender, recipient, transferAmount);
    }

    function mintHumanAddress(address to, uint256 desiredAmountToMint)
        external
        notPausedContract
        onlyRole(ROLE_MINTER)
    {
        _mintHumanAddress(to, desiredAmountToMint);
        emit MintHumanAddress(to, desiredAmountToMint);
    }

    function _mintHumanAddress(address to, uint256 desiredAmountToMint)
        private
        recipientIsNotBurnAddress(to)
    {
        _balances[to] += desiredAmountToMint;
        _totalSupply += desiredAmountToMint;

        emit Transfer(BURN_ADDRESS, to, desiredAmountToMint);
    }

    function burnHumanAddress(address from, uint256 desiredAmountToBurn)
        external
        notPausedContract
        onlyRole(ROLE_BURNER)
    {
        _burnHumanAddress(from, desiredAmountToBurn);
        emit BurnHumanAddress(from, desiredAmountToBurn);
    }

    function _burnHumanAddress(address from, uint256 desiredAmountToBurn)
        private
    {
        _balances[from] -= desiredAmountToBurn;
        _totalSupply -= desiredAmountToBurn;

        emit Transfer(from, BURN_ADDRESS, desiredAmountToBurn);
    }

    function getChainId() external view returns (uint256) {
        return block.chainid;
    }
}
