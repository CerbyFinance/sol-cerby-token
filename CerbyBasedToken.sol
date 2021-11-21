// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "./interfaces/ICerbyToken.sol";
import "./interfaces/ICerbyBotDetection.sol";
import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./openzeppelin/token/ERC20/extensions/draft-ERC20Permit.sol";

contract CerbyBasedToken is Context, AccessControlEnumerable, ERC20Mod, ERC20Permit {
    bytes32 public constant ROLE_MINTER = keccak256("ROLE_MINTER");
    bytes32 public constant ROLE_BURNER = keccak256("ROLE_BURNER");
    bytes32 public constant ROLE_TRANSFERER = keccak256("ROLE_TRANSFERER");
    bytes32 public constant ROLE_MODERATOR = keccak256("ROLE_MODERATOR");
    
    uint constant CERBY_BOT_DETECTION_CONTRACT_ID = 3;
    
    address constant CERBY_TOKEN_CONTRACT_ADDRESS = 0xdef1fac7Bf08f173D286BbBDcBeeADe695129840;
    
    address constant BURN_ADDRESS = address(0x0);
    
    address[] utilsContracts;
    
    bool public isPaused;
    
    event TransferCustom(address sender, address recipient, uint amount);
    event MintHumanAddress(address recipient, uint amount);
    event BurnHumanAddress(address sender, uint amount);
    
    event MintedByBridge(address recipient, uint amount);
    event BurnedByBridge(address sender, uint amount);

    constructor() 
        ERC20Mod("Cerby Token", "CERBY") 
        ERC20Permit("Cerby Token")
    {
        _setupRole(ROLE_ADMIN, _msgSender());
        _setupRole(ROLE_MINTER, _msgSender());
        _setupRole(ROLE_BURNER, _msgSender());
        _setupRole(ROLE_TRANSFERER, _msgSender());
        _setupRole(ROLE_MODERATOR, _msgSender());
    }
    
    modifier checkTransaction(address sender, address recipient, uint transferAmount)
    {
        ICerbyBotDetection iCerbyBotDetection = ICerbyBotDetection(
            ICerbyToken(CERBY_TOKEN_CONTRACT_ADDRESS).getUtilsContractAtPos(CERBY_BOT_DETECTION_CONTRACT_ID)
        );
        iCerbyBotDetection.checkTransactionInfo(
            CERBY_TOKEN_CONTRACT_ADDRESS, 
            sender, 
            recipient, 
            tokenBalances[recipient], 
            transferAmount
        );
        _;
    }
    
    modifier notPausedContract {
        require(
            !isPaused,
            "T: paused"
        );
        _;
    }
    
    modifier pausedContract {
        require(
            isPaused,
            "T: !paused"
        );
        _;
    }
    
    modifier recipientIsNotBurnAddress(address recipient) {
        require(
            recipient != BURN_ADDRESS,
            "T: !burn"
        );
        _;
    }
    
    function updateNameAndSymbol(string calldata __name, string calldata __symbol)
        external
        onlyRole(ROLE_ADMIN)
    {
        _name = __name;
        _symbol = __symbol;
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
    
    function transfer(address recipient, uint256 amount) 
        public 
        notPausedContract
        virtual 
        override 
        returns (bool) 
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) 
        public 
        notPausedContract
        recipientIsNotBurnAddress(recipient)
        virtual 
        override 
        returns (bool) 
    {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "T: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }
    
    function moderatorTransferFromWhilePaused(address sender, address recipient, uint256 amount) 
        external 
        pausedContract
        onlyRole(ROLE_MODERATOR)
        recipientIsNotBurnAddress(recipient)
        returns (bool) 
    {
        _transfer(sender, recipient, amount);

        return true;
    }
    
    function transferCustom(address sender, address recipient, uint256 amount)
        external
        notPausedContract
        onlyRole(ROLE_TRANSFERER)
        recipientIsNotBurnAddress(recipient)
    {
        _transfer(sender, recipient, amount);
        
        emit TransferCustom(sender, recipient, amount);
    }
    
    function _transfer(address sender, address recipient, uint transferAmount) 
        internal
        virtual 
        recipientIsNotBurnAddress(recipient)
        checkTransaction(sender, recipient, transferAmount)
        override 
    {
        
        tokenBalances[sender] -= transferAmount;
        tokenBalances[recipient] += transferAmount;
        
        emit Transfer(sender, recipient, transferAmount);
    }
    
    function mintByBridge(address to, uint desiredAmountToMint) 
        external
        notPausedContract
        onlyRole(ROLE_MINTER)
    {
        _mintHumanAddress(to, desiredAmountToMint);
        emit MintedByBridge(to, desiredAmountToMint);
    }
    
    function mintHumanAddress(address to, uint desiredAmountToMint) 
        external
        notPausedContract
        onlyRole(ROLE_MINTER)
    {
        _mintHumanAddress(to, desiredAmountToMint);
        emit MintHumanAddress(to, desiredAmountToMint);
    }
    
    function _mintHumanAddress(address to, uint desiredAmountToMint) 
        private
        recipientIsNotBurnAddress(to)
        checkTransaction(BURN_ADDRESS, to, desiredAmountToMint)
    {
        tokenBalances[to] += desiredAmountToMint;
        totalTokenSupply += desiredAmountToMint;
        
        emit Transfer(BURN_ADDRESS, to, desiredAmountToMint);
    }

    function burnByBridge(address from, uint desiredAmountToBurn)
        external
        notPausedContract
        onlyRole(ROLE_BURNER)
    {
        _burnHumanAddress(from, desiredAmountToBurn);
        emit BurnedByBridge(from, desiredAmountToBurn);
    }

    function burnHumanAddress(address from, uint desiredAmountToBurn)
        external
        notPausedContract
        onlyRole(ROLE_BURNER)
    {
        _burnHumanAddress(from, desiredAmountToBurn);
        emit BurnHumanAddress(from, desiredAmountToBurn);
    }

    function _burnHumanAddress(address from, uint desiredAmountToBurn)
        private
        checkTransaction(from, BURN_ADDRESS, desiredAmountToBurn)
    {
        tokenBalances[from] -= desiredAmountToBurn;
        totalTokenSupply -= desiredAmountToBurn;
        
        emit Transfer(from, BURN_ADDRESS, desiredAmountToBurn);
    }
    
    function getChainId() 
        external 
        view 
        returns (uint) 
    {
        return block.chainid;
    }
}
