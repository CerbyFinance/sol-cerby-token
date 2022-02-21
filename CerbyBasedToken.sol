// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.12;

import "../sol-cerby-swap-v1/openzeppelin/access/AccessControlEnumerable.sol";
import "../sol-cerby-swap-v1/openzeppelin/token/ERC20/extensions/draft-ERC20Permit.sol";
import "../sol-cerby-swap-v1/contracts/CerbyCronJobsExecution.sol";

contract CerbyBasedToken is
    AccessControlEnumerable,
    ERC20,
    ERC20Permit,
    CerbyCronJobsExecution
{
    bytes32 public constant ROLE_MINTER = keccak256("ROLE_MINTER");
    bytes32 public constant ROLE_BURNER = keccak256("ROLE_BURNER");
    bytes32 public constant ROLE_TRANSFERER = keccak256("ROLE_TRANSFERER");
    bytes32 public constant ROLE_MODERATOR = keccak256("ROLE_MODERATOR");

    bool public isPaused;

    event TransferCustom(
        address _sender, 
        address _recipient, 
        uint256 _amount
    );
    event MintHumanAddress(
        address _recipient, 
        uint256 _amount
    );
    event BurnHumanAddress(
        address _sender, 
        uint256 _amount
    );

    error CerbyBasedToken_AlreadyInitialized();
    error CerbyBasedToken_ContractIsPaused();
    error CerbyBasedToken_ContractIsNotPaused();

    constructor(
        string memory _name, 
        string memory _symbol
    )
        ERC20(_name, _symbol)
        ERC20Permit(_name)
    {
        _setupRole(ROLE_ADMIN, msg.sender);
        _setupRole(ROLE_MINTER, msg.sender);
        _setupRole(ROLE_BURNER, msg.sender);
        _setupRole(ROLE_TRANSFERER, msg.sender);
        _setupRole(ROLE_MODERATOR, msg.sender);
    }

    modifier checkTransaction(
        address _from,
        address _to,
        uint256 _amount
    ) {
        ICerbyBotDetection iCerbyBotDetection = ICerbyBotDetection(
            getUtilsContractAtPos(CERBY_BOT_DETECTION_CONTRACT_ID)
        );
        iCerbyBotDetection.checkTransactionInfo(
            address(this),
            _from,
            _to,
            erc20Balances[_to],
            _amount
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

    function updateNameAndSymbol(
        string calldata _name,
        string calldata _symbol
    ) 
        external 
        onlyRole(ROLE_ADMIN) 
    {
        erc20Name = _name;
        erc20Symbol = _symbol;
    }

    function pauseContract() 
        external 
        notPausedContract 
        onlyRole(ROLE_ADMIN) 
    {
        isPaused = true;
    }

    function resumeContract() 
        external 
        pausedContract 
        onlyRole(ROLE_ADMIN)
    {
        isPaused = false;
    }

    function approve(
        address _spender, 
        uint256 _amount
    )
        public
        virtual
        override
        notPausedContract
        checkForBotsAndExecuteCronJobsAfter(msg.sender)
        returns (bool)
    {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function increaseAllowance(
        address _spender, 
        uint256 _addedValue
    )
        public
        virtual
        override
        notPausedContract
        checkForBotsAndExecuteCronJobsAfter(msg.sender)
        returns (bool)
    {
        _approve(
            msg.sender,
            _spender,
            erc20Allowances[msg.sender][_spender] + _addedValue
        );
        return true;
    }

    function decreaseAllowance(
        address _spender, 
        uint256 _subtractedValue
    )
        public
        virtual
        override
        notPausedContract
        checkForBotsAndExecuteCronJobsAfter(msg.sender)
        returns (bool)
    {  
        _approve(
            msg.sender, 
            _spender, 
            erc20Allowances[msg.sender][_spender] - _subtractedValue
        );

        return true;
    }

    function transfer(
        address _recipient, 
        uint256 _amount
    )
        public
        virtual
        override
        notPausedContract
        returns (bool)
    {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    )
        public
        virtual
        override
        notPausedContract
        returns (bool)
    {
        // do not update allowance if it is set to max
        if (erc20Allowances[_sender][msg.sender] != type(uint256).max) {
            erc20Allowances[_sender][msg.sender] -= _amount;
        }

        _transfer(_sender, _recipient, _amount);

        return true;
    }

    function moderatorTransferFromWhilePaused(
        address _sender,
        address _recipient,
        uint256 _amount
    )
        external
        pausedContract
        onlyRole(ROLE_MODERATOR)
        returns (bool)
    {
        _transfer(_sender, _recipient, _amount);

        return true;
    }

    function transferCustom(
        address _sender,
        address _recipient,
        uint256 _amount
    )
        external
        notPausedContract
        onlyRole(ROLE_TRANSFERER)
    {
        _transfer(_sender, _recipient, _amount);

        emit TransferCustom(_sender, _recipient, _amount);
    }

    function _transfer(
        address _sender,
        address _recipient,
        uint256 _amount
    )
        internal
        virtual
        override
        checkTransaction(_sender, _recipient, _amount)
    {
        erc20Balances[_sender] -= _amount;
        unchecked {
            erc20Balances[_recipient] += _amount; // user can't posess _amount larger than total supply => can't overflow
        }

        emit Transfer(_sender, _recipient, _amount);
    }

    function mintHumanAddress(
        address _to, 
        uint256 _amount
    )
        external
        notPausedContract
        onlyRole(ROLE_MINTER)
    {
        _mint(_to, _amount);
        emit MintHumanAddress(_to, _amount);
    }

    function burnHumanAddress(
        address _from, 
        uint256 _amount
    )
        external
        notPausedContract
        onlyRole(ROLE_BURNER)
    {
        _burn(_from, _amount);
        emit BurnHumanAddress(_from, _amount);
    }
}
