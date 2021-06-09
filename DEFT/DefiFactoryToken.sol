// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../interfaces/INoBotsTech.sol";
import "../openzeppelin/access/AccessControlEnumerable.sol";
import "../openzeppelin/token/ERC20/extensions/draft-ERC20Permit.sol";



contract DefiFactoryToken is Context, AccessControlEnumerable, ERC20Mod, ERC20Permit {
    bytes32 public constant ROLE_MINTER = keccak256("ROLE_MINTER");
    bytes32 public constant ROLE_BURNER = keccak256("ROLE_BURNER");
    bytes32 public constant ROLE_TRANSFERER = keccak256("ROLE_TRANSFERER");
    bytes32 public constant ROLE_MODERATOR = keccak256("ROLE_MODERATOR");
    bytes32 public constant ROLE_TAXER = keccak256("ROLE_TAXER");
    
    uint constant NOBOTS_TECH_CONTRACT_ID = 0;
    uint constant TEAM_VESTING_CONTRACT_ID = 1;
    
    address[] utilsContracts;
    
    struct AccessSettings {
        bool isMinter;
        bool isBurner;
        bool isTransferer;
        bool isModerator;
        bool isTaxer;
        
        address addr;
    }
    
    bool public isPaused;
    
    address constant BURN_ADDRESS = address(0x0);
    
    event VestedAmountClaimed(address recipient, uint amount);
    event UpdatedUtilsContracts(AccessSettings[] accessSettings);
    event TransferCustom(address sender, address recipient, uint amount);
    event MintHumanAddress(address recipient, uint amount);
    event BurnHumanAddress(address sender, uint amount);
    event ClaimedReferralRewards(address recipient, uint amount);
    
    event MintedByBridge(address recipient, uint amount);
    event BurnedByBridge(address sender, uint amount);





    constructor() 
        ERC20Mod("tDefi Factory Token", "tDEFT") 
        ERC20Permit("tDefi Factory Token")
    {
        _setupRole(ROLE_ADMIN, _msgSender());
        _setupRole(ROLE_MINTER, _msgSender());
        _setupRole(ROLE_BURNER, _msgSender());
        _setupRole(ROLE_TRANSFERER, _msgSender());
        _setupRole(ROLE_MODERATOR, _msgSender());
        _setupRole(ROLE_TAXER, _msgSender());
    }
    
    modifier notPausedContract {
        require(
            !isPaused,
            "DEFT: paused"
        );
        _;
    }
    
    modifier pausedContract {
        require(
            isPaused,
            "DEFT: !paused"
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
    
    function balanceOf(address account) 
        public 
        view 
        override 
        returns(uint) 
    {
        return INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]).
            getBalance(account, _RealBalances[account]);
    }
    
    function totalSupply() 
        public 
        view 
        override 
        returns (uint) 
    {
        return INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]).
            getTotalSupply();
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
        virtual 
        override 
        returns (bool) 
    {
        require(
            sender != BURN_ADDRESS,
            "DEFT: !burn"
        );
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "DEFT: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }
    
    function moderatorTransferFromWhilePaused(address sender, address recipient, uint256 amount) 
        external 
        pausedContract
        onlyRole(ROLE_MODERATOR)
        returns (bool) 
    {
        require(
            sender != BURN_ADDRESS,
            "DEFT: !burn"
        );
        _transfer(sender, recipient, amount);

        return true;
    }
    
    function transferCustom(address sender, address recipient, uint256 amount)
        external
        notPausedContract
        onlyRole(ROLE_TRANSFERER)
    {
        require(
            sender != BURN_ADDRESS,
            "DEFT: !burn"
        );
        _transfer(sender, recipient, amount);
        
        emit TransferCustom(sender, recipient, amount);
    }
    
    function _transfer(address sender, address recipient, uint amount) 
        internal
        virtual 
        override 
    {
        require(
            recipient != BURN_ADDRESS,
            "DEFT: !burn"
        );
        require(
            sender != recipient,
            "DEFT: !self"
        );
        
        INoBotsTech iNoBotsTech = INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]);
        TaxAmountsOutput memory taxAmountsOutput = iNoBotsTech.prepareTaxAmounts(
            TaxAmountsInput(
                sender,
                recipient,
                amount,
                _RealBalances[sender],
                _RealBalances[recipient]
            )
        );
        
        _RealBalances[sender] = taxAmountsOutput.senderRealBalance;
        _RealBalances[recipient] = taxAmountsOutput.recipientRealBalance;
        
        emit Transfer(sender, recipient, taxAmountsOutput.recipientGetsAmount);
        if (taxAmountsOutput.burnAndRewardAmount > 0)
        {
            emit Transfer(sender, BURN_ADDRESS, taxAmountsOutput.burnAndRewardAmount);
        }
    }
    
    function transferFromTeamVestingContract(address recipient, uint256 amount)
        external
        notPausedContract
    {
        address vestingContract = utilsContracts[TEAM_VESTING_CONTRACT_ID];
        require(vestingContract == _msgSender(), "DEFT: !VESTING_CONTRACT");
        
        INoBotsTech iNoBotsTech = INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]);
        _RealBalances[vestingContract] -= amount;
        _RealBalances[recipient] += 
            iNoBotsTech.getRealBalanceTeamVestingContract(amount);
        
        iNoBotsTech.publicForcedUpdateCacheMultiplier();
        
        emit Transfer(vestingContract, recipient, amount);
        emit VestedAmountClaimed(recipient, amount);
    }
    
    function registerReferral(address referrer)
        public
    {
        INoBotsTech iNoBotsTech = INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]);
        return iNoBotsTech.registerReferral(_msgSender(), referrer);
    }
    
    function getTemporaryReferralRealAmountsBulk(address[] calldata addrs)
        external
        view
        returns (TemporaryReferralRealAmountsBulk[] memory)
    {
        INoBotsTech iNoBotsTech = INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]);
        return iNoBotsTech.getTemporaryReferralRealAmountsBulk(addrs);
    }
    
    function getCachedReferrerRewards(address addr)
        external
        view
        returns(uint)
    {
        INoBotsTech iNoBotsTech = INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]);
        return iNoBotsTech.getCachedReferrerRewards(addr);
    }
    
    function getCalculatedReferrerRewards(address addr, address[] calldata referrals)
        external
        view
        returns(uint)
    {
        INoBotsTech iNoBotsTech = INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]);
        return iNoBotsTech.getCalculatedReferrerRewards(addr, referrals);
    }
    
    function filterNonZeroReferrals(address[] calldata referrals)
        external
        view
        returns (address[] memory)
    {
        INoBotsTech iNoBotsTech = INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]);
        return iNoBotsTech.filterNonZeroReferrals(referrals);
    }
    
    function claimReferrerRewards(address[] calldata referrals)
        external
        notPausedContract
    {
        INoBotsTech iNoBotsTech = INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]);
        iNoBotsTech.updateReferrersRewards(referrals);
        
        uint rewards = iNoBotsTech.getCachedReferrerRewards(_msgSender());
        require(rewards > 0, "DEFT: !rewards");
        
        iNoBotsTech.clearReferrerRewards(_msgSender());
        _mintHumanAddress(_msgSender(), rewards);
        
        emit ClaimedReferralRewards(_msgSender(), rewards);
    }
    
    function chargeCustomTax(address from, uint amount)
        external
        notPausedContract
        onlyRole(ROLE_TAXER)
    {
        INoBotsTech iNoBotsTech = INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]);
        _RealBalances[from] = iNoBotsTech.chargeCustomTax(amount, _RealBalances[from]);
    }
    
    function updateUtilsContracts(AccessSettings[] calldata accessSettings)
        external
        onlyRole(ROLE_ADMIN)
    {
        for(uint i = 0; i < utilsContracts.length; i++)
        {
            revokeRole(ROLE_MINTER, utilsContracts[i]);
            revokeRole(ROLE_BURNER, utilsContracts[i]);
            revokeRole(ROLE_TRANSFERER, utilsContracts[i]);
            revokeRole(ROLE_MODERATOR, utilsContracts[i]);
            revokeRole(ROLE_TAXER, utilsContracts[i]);
        }
        delete utilsContracts;
        
        for(uint i = 0; i < accessSettings.length; i++)
        {
            if (accessSettings[i].isMinter) grantRole(ROLE_MINTER, accessSettings[i].addr);
            if (accessSettings[i].isBurner) grantRole(ROLE_BURNER, accessSettings[i].addr);
            if (accessSettings[i].isTransferer) grantRole(ROLE_TRANSFERER, accessSettings[i].addr);
            if (accessSettings[i].isModerator) grantRole(ROLE_MODERATOR, accessSettings[i].addr);
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
    {
        INoBotsTech iNoBotsTech = INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]);
        uint realAmountToMint = 
            iNoBotsTech.
                prepareHumanAddressMintOrBurnRewardsAmounts(
                    true,
                    to,
                    desiredAmountToMint
                );
        
        _RealBalances[to] += realAmountToMint;
        iNoBotsTech.publicForcedUpdateCacheMultiplier();
        
        emit Transfer(address(0), to, desiredAmountToMint);
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
    {
        INoBotsTech iNoBotsTech = INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]);
        uint realAmountToBurn = 
            INoBotsTech(utilsContracts[NOBOTS_TECH_CONTRACT_ID]).
                prepareHumanAddressMintOrBurnRewardsAmounts(
                    false,
                    from,
                    desiredAmountToBurn
                );
        
        _RealBalances[from] -= realAmountToBurn;
        iNoBotsTech.publicForcedUpdateCacheMultiplier();
        
        emit Transfer(from, address(0), desiredAmountToBurn);
    }
    
    function getChainId() 
        external 
        view 
        returns (uint) 
    {
        return block.chainid;
    }
}
