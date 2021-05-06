// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./openzeppelin/token/ERC20/extensions/draft-ERC20Permit.sol";
import "./INoBotsTech.sol";



contract DefiFactoryToken is Context, AccessControlEnumerable, ERC20, ERC20Permit {
    bytes32 public constant ROLE_MINTER = keccak256("ROLE_MINTER");
    bytes32 public constant ROLE_BURNER = keccak256("ROLE_BURNER");
    bytes32 public constant ROLE_TRANSFERER = keccak256("ROLE_TRANSFERER");
    bytes32 public constant ROLE_ALLOWED_TO_SEND_WHILE_PAUSED = keccak256("ROLE_ALLOWED_TO_SEND_WHILE_PAUSED");
    bytes32 public constant ROLE_TAXER = keccak256("ROLE_TAXER");
    
    uint constant NOBOTS_TECH_CONTRACT_ID = 0;
    uint constant TEAM_VESTING_CONTRACT_ID = 1;
    
    
    address[] utilsContracts;
    
    struct AccessSettings {
        bool isMinter;
        bool isBurner;
        bool isTransferer;
        bool isAllowedToSend;
        bool isTaxer;
        
        address addr;
    }
    
    bool isPaused;
    address[] allowedToSend;
    
    address constant BURN_ADDRESS = address(0x0);
    
    event VestedAmountClaimed(address recipient, uint amount);
    event UpdatedUtilsContracts(AccessSettings[] accessSettings);
    event TransferCustom(address sender, address recipient, uint amount);
    event MintHumanAddress(address recipient, uint amount);
    event BurnHumanAddress(address sender, uint amount);
    event ClaimedReferralRewards(address recipient, uint amount);

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `BURNER_ROLE` to the
     * account that deploys the contract.
     *
     * See {ERC20-constructor}.
     */
    constructor() 
        ERC20("Test VVV", "VVV") 
        ERC20Permit("Test VVV")
    {
        _setupRole(ROLE_ADMIN, _msgSender());
        _setupRole(ROLE_MINTER, _msgSender());
        _setupRole(ROLE_BURNER, _msgSender());
        _setupRole(ROLE_TRANSFERER, _msgSender());
    }
    
    modifier onlyAdmins {
        require(hasRole(ROLE_ADMIN, _msgSender()), "DefiFactoryToken: !ROLE_ADMIN");
        _;
    }
    
    modifier canBePaused {
        require(
            !isPaused || 
            hasRole(ROLE_ALLOWED_TO_SEND_WHILE_PAUSED, _msgSender()) || 
            hasRole(ROLE_ADMIN, _msgSender()),
            "DefiFactoryToken: !ROLE_ALLOWED_TO_SEND_WHILE_PAUSED"
        );
        _;
    }
    
    function balanceOf(address account) public virtual view override returns(uint) {
        return INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]).
            getBalance(account, _balances[account]);
    }
    
    function totalSupply() public virtual view override returns (uint) {
        return INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]).
            getTotalSupply();
    }
    
    function pauseContract(address[] calldata _allowedToSend)
        public
        onlyAdmins
    {
        isPaused = true;
        allowedToSend = _allowedToSend;
        
        for(uint i = 0; i < _allowedToSend.length; i++)
        {
            _setupRole(ROLE_ALLOWED_TO_SEND_WHILE_PAUSED, _allowedToSend[i]);
        }
    }
    
    function resumeContract()
        public
        onlyAdmins
    {
        isPaused = false;
        for(uint i = 0; i < allowedToSend.length; i++)
        {
            revokeRole(ROLE_ALLOWED_TO_SEND_WHILE_PAUSED, allowedToSend[i]);
        }
        delete allowedToSend;
    }
    
    function _transfer(address sender, address recipient, uint amount) 
        internal 
        canBePaused
        virtual 
        override 
    {
        require(
            sender != BURN_ADDRESS &&
            recipient != BURN_ADDRESS,
            "DefiFactoryToken: !burn"
        );
        require(
            sender != recipient,
            "DefiFactoryToken: !self"
        );
        
        INoBotsTech iNoBotsTech = INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]);
        TaxAmountsOutput memory taxAmountsOutput = iNoBotsTech.prepareTaxAmounts(
            TaxAmountsInput(
                sender,
                recipient,
                amount,
                _balances[sender],
                _balances[recipient]
            )
        );
        
        _balances[sender] = taxAmountsOutput.senderBalance;
        _balances[recipient] = taxAmountsOutput.recipientBalance;
        
        emit Transfer(sender, BURN_ADDRESS, taxAmountsOutput.burnAndRewardAmount);
        emit Transfer(sender, recipient, taxAmountsOutput.recipientGetsAmount);
    }
    
    function registerReferral(address referrer)
        public
    {
        INoBotsTech iNoBotsTech = INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]);
        return iNoBotsTech.registerReferral(_msgSender(), referrer);
    }
    
    // TODO: get temporary referrer balances bulk
    
    struct Referrals {
        address referral;
        address referrer;
    }
    
    // TODO: remove on production!!!!!!!!!
    
    function registerReferralsBulk(Referrals[] memory referrals)
        public
    {
        INoBotsTech iNoBotsTech = INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]);
        for(uint i = 0; i<referrals.length; i++)
        {
            iNoBotsTech.registerReferral(referrals[i].referral, referrals[i].referrer);
        }
    }
    
    function getCachedReferrerRewards(address addr)
        public
        view
        returns(uint)
    {
        INoBotsTech iNoBotsTech = INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]);
        return iNoBotsTech.getCachedReferrerRewards(addr);
    }
    
    function getCalculatedReferrerRewards(address addr, address[] calldata referrals)
        public
        view
        returns(uint)
    {
        INoBotsTech iNoBotsTech = INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]);
        return iNoBotsTech.getCalculatedReferrerRewards(addr, referrals);
    }
    
    function filterNonZeroReferrals(address[] calldata referrals)
        public
        view
        returns (address[] memory)
    {
        INoBotsTech iNoBotsTech = INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]);
        return iNoBotsTech.filterNonZeroReferrals(referrals);
    }
    
    function claimReferrerRewards(address[] calldata referrals)
        public
        canBePaused
    {
        INoBotsTech iNoBotsTech = INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]);
        iNoBotsTech.updateReferrersRewards(referrals);
        
        uint rewards = iNoBotsTech.getCachedReferrerRewards(_msgSender());
        require(rewards > 0, "DefiFactoryToken: !rewards");
        
        iNoBotsTech.clearReferrerRewards(_msgSender());
        _mintHumanAddress(_msgSender(), rewards);
        
        emit ClaimedReferralRewards(_msgSender(), rewards);
    }
    
    function chargeCustomTax(address from, uint amount)
        public
        canBePaused
    {
        require(hasRole(ROLE_TAXER, _msgSender()), "DefiFactoryToken: !ROLE_TAXER");
        
        INoBotsTech iNoBotsTech = INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]);
        _balances[from] = iNoBotsTech.chargeCustomTax(amount, _balances[from]);
    }
    
    function updateUtilsContracts(AccessSettings[] calldata accessSettings)
        public
        onlyAdmins
    {
        for(uint i = 0; i < utilsContracts.length; i++)
        {
            revokeRole(ROLE_MINTER, utilsContracts[i]);
            revokeRole(ROLE_BURNER, utilsContracts[i]);
            revokeRole(ROLE_TRANSFERER, utilsContracts[i]);
            revokeRole(ROLE_ALLOWED_TO_SEND_WHILE_PAUSED, utilsContracts[i]);
            revokeRole(ROLE_TAXER, utilsContracts[i]);
        }
        delete utilsContracts;
        
        for(uint i = 0; i < accessSettings.length; i++)
        {
            if (accessSettings[i].isMinter) grantRole(ROLE_MINTER, accessSettings[i].addr);
            if (accessSettings[i].isBurner) grantRole(ROLE_BURNER, accessSettings[i].addr);
            if (accessSettings[i].isTransferer) grantRole(ROLE_TRANSFERER, accessSettings[i].addr);
            if (accessSettings[i].isAllowedToSend) grantRole(ROLE_ALLOWED_TO_SEND_WHILE_PAUSED, accessSettings[i].addr);
            if (accessSettings[i].isTaxer) grantRole(ROLE_TAXER, accessSettings[i].addr);
            
            utilsContracts.push(accessSettings[i].addr);
        }
        
        emit UpdatedUtilsContracts(accessSettings);
    }
    
    function getUtilsContractAtPos(uint pos)
        external
        view
        returns (address)
    {
        return utilsContracts[pos];
    }
    
    function getUtilsContractsCount()
        external
        view
        returns(uint)
    {
        return utilsContracts.length;
    }
    
    // 0x539FaA851D86781009EC30dF437D794bCd090c8F,1000000000000000000000000
    function mintHumanAddress(address to, uint desiredAmountToMint) 
        public
    {
        require(hasRole(ROLE_MINTER, _msgSender()), "DefiFactoryToken: !ROLE_MINTER");
        
        _mintHumanAddress(to, desiredAmountToMint);
    }
    
    function _mintHumanAddress(address to, uint desiredAmountToMint) 
        internal
        canBePaused
    {
        uint realAmountToMint = 
            INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]).
                prepareHumanAddressMintOrBurnRewardsAmounts(
                    true,
                    to,
                    desiredAmountToMint
                );
        
        _balances[to] += realAmountToMint;
        emit Transfer(address(0), to, desiredAmountToMint);
        
        emit MintHumanAddress(to, desiredAmountToMint);
    }

    function burnHumanAddress(address from, uint desiredAmountToBurn)
        public
    {
        require(hasRole(ROLE_BURNER, _msgSender()), "DefiFactoryToken: !ROLE_BURNER");
        
        _burnHumanAddress(from, desiredAmountToBurn);
    }

    function _burnHumanAddress(address from, uint desiredAmountToBurn)
        internal
        canBePaused
    {
         uint realAmountToBurn = 
            INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]).
                prepareHumanAddressMintOrBurnRewardsAmounts(
                    false,
                    from,
                    desiredAmountToBurn
                );
        
        require(_balances[from] >= realAmountToBurn, "DefiFactoryToken: amount gt balance");
        
        _balances[from] -= realAmountToBurn;
        emit Transfer(from, address(0), desiredAmountToBurn);
        
        emit BurnHumanAddress(from, desiredAmountToBurn);
    }
    
    function transferFromTeamVestingContract(address recipient, uint256 amount)
        public
        canBePaused
    {
        address vestingContract = utilsContracts[TEAM_VESTING_CONTRACT_ID];
        require(vestingContract == _msgSender(), "DefiFactoryToken: !VESTING_CONTRACT");
        
        require(_balances[vestingContract] >= amount, "DefiFactoryToken: !amount");
        
        _balances[vestingContract] -= amount;
        _balances[recipient] += 
            INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]).
                getRealBalanceVestingContract(amount);
        
        
        emit Transfer(vestingContract, recipient, amount);
        emit VestedAmountClaimed(recipient, amount);
    }
    
    function transferCustom(address sender, address recipient, uint256 amount)
        public
        canBePaused
    {
        require(hasRole(ROLE_TRANSFERER, _msgSender()), "DefiFactoryToken: !ROLE_TRANSFERER");
        
        _transfer(sender, recipient, amount);
        
        emit TransferCustom(sender, recipient, amount);
    }
    
    function getChainId() external view returns (uint) {
        return block.chainid;
    }
}
