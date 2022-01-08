// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.11;


import "./openzeppelin/access/Ownable.sol";
import "./openzeppelin/token/ERC1155/extensions/ERC1155Supply.sol";
import "./CerbyCronJobsExecution.sol";


contract CerbySwapLP1155V1 is ERC1155Supply, CerbyCronJobsExecution, Ownable {

    constructor()
        ERC1155("")
    {

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

    function ownerSetURI(string memory newuri) 
        public
        // TODO: enable on production
        //onlyOwner
    {
        _uri = newuri;
    }

    function ownerMint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) 
        public
        // TODO: enable on production
        /*onlyOwner
        executeCronJobs()*/
    {
        _mint(to, id, amount, data);
    }

    function ownerMintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) 
        public
        // TODO: enable on production
        /*onlyOwner
        executeCronJobs()*/
    {
        _mintBatch(to, ids, amounts, data);
    }

    function ownerBurn(
        address from,
        uint256 id,
        uint256 amount
    ) 
        public
        // TODO: enable on production
        /*onlyOwner
        executeCronJobs()*/
    {
        _burn(from, id, amount);
    }

    function ownerBurnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) 
        public
        // TODO: enable on production
        /*onlyOwner
        executeCronJobs()*/
    {
        _burnBatch(from, ids, amounts);
    }
}