// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.10;

import "./CerbyBasedToken.sol";

contract CerbyToken is CerbyBasedToken {
    
    
    address[] utilsContracts;
    
    event UpdatedUtilsContracts(AccessSettings[] accessSettings);
    
    
    constructor()
        CerbyBasedToken("Cerby Token2", "CERBY2")
    {
        initializeOwner(msg.sender);
        
        AccessSettings[] memory accessSettings = new AccessSettings[](4);
        accessSettings[CERBY_BOT_DETECTION_CONTRACT_ID].addr = 0x38BDBF0Fa0D7Ed0E3B74Ed99fB88dc9341af0d1f;
        
        updateUtilsContracts(accessSettings);
    }
    
    
    
    // ----------------------
    
    function updateUtilsContracts(AccessSettings[] memory accessSettings)
        public
        onlyRole(ROLE_ADMIN)
    {
        for(uint i = 0; i < utilsContracts.length; i++)
        {
            revokeRole(ROLE_MINTER, utilsContracts[i]);
            revokeRole(ROLE_BURNER, utilsContracts[i]);
            revokeRole(ROLE_TRANSFERER, utilsContracts[i]);
            revokeRole(ROLE_MODERATOR, utilsContracts[i]);
        }
        delete utilsContracts;
        
        for(uint i = 0; i < accessSettings.length; i++)
        {
            if (accessSettings[i].isMinter) grantRole(ROLE_MINTER, accessSettings[i].addr);
            if (accessSettings[i].isBurner) grantRole(ROLE_BURNER, accessSettings[i].addr);
            if (accessSettings[i].isTransferer) grantRole(ROLE_TRANSFERER, accessSettings[i].addr);
            if (accessSettings[i].isModerator) grantRole(ROLE_MODERATOR, accessSettings[i].addr);
            
            utilsContracts.push(accessSettings[i].addr);
        }
        
        emit UpdatedUtilsContracts(accessSettings);
    }
    
    function getUtilsContractAtPos(uint pos)
        public
        override
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
}