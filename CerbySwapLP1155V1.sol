// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.11;


import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./openzeppelin/token/ERC1155/extensions/ERC1155Supply.sol";
import "./CerbyCronJobsExecution.sol";


contract CerbySwapLP1155V1 is ERC1155Supply, CerbyCronJobsExecution, AccessControlEnumerable {

    constructor()
        ERC1155("")
    {
        _setupRole(ROLE_ADMIN, msg.sender);
    }

    function setApprovalForAll(address operator, bool approved) 
        public 
        virtual 
        override
        executeCronJobs()
        checkForBots(msg.sender)
    {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) 
        public 
        virtual 
        override
        executeCronJobs()
        checkForBots(msg.sender)
    {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }
    
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) 
        public 
        virtual 
        override
        // TODO: enable on production
        /*executeCronJobs()
        checkForBots(msg.sender) */
    {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: transfer caller is not owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function adminSafeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) 
        public
        onlyRole(ROLE_ADMIN)
        executeCronJobs()
        checkForBots(msg.sender)
    {
        _safeTransferFrom(from, to, id, amount, data);
    }
    
    function adminSafeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) 
        public 
        onlyRole(ROLE_ADMIN)
        executeCronJobs()
        checkForBots(msg.sender)
    {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: transfer caller is not owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function adminSetURI(string memory newuri) 
        public
        onlyRole(ROLE_ADMIN)
    {
        _uri = newuri;
    }

    function adminMint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) 
        public
        // TODO: enable on production
        /*onlyRole(ROLE_ADMIN)
        executeCronJobs()*/
    {
        _mint(to, id, amount, data);
    }

    function adminMintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) 
        public
        // TODO: enable on production
        /*onlyRole(ROLE_ADMIN)
        executeCronJobs()*/
    {
        _mintBatch(to, ids, amounts, data);
    }

    function adminBurn(
        address from,
        uint256 id,
        uint256 amount
    ) 
        public
        // TODO: enable on production
        /*onlyRole(ROLE_ADMIN)
        executeCronJobs()*/
    {
        _burn(from, id, amount);
    }

    function adminBurnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) 
        public
        // TODO: enable on production
        /*onlyRole(ROLE_ADMIN)
        executeCronJobs()*/
    {
        _burnBatch(from, ids, amounts);
    }
}