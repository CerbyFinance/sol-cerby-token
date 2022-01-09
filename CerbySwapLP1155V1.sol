// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.11;


import "./openzeppelin/access/AccessControlEnumerable.sol";
import "./openzeppelin/token/ERC1155/extensions/ERC1155Supply.sol";
import "./CerbyCronJobsExecution.sol";


contract CerbySwapLP1155V1 is ERC1155Supply, CerbyCronJobsExecution, AccessControlEnumerable {

    string _name = "CerbySwap LP1155 Tokens V1";
    string _symbol = "CERBY_SWAP_V1";
    string _urlPrefix = "https://data.cerby.fi/CerbySwap/v1/";

    constructor()
        ERC1155(string(abi.encodePacked(_urlPrefix, "{id}.json")))
    {
        _setupRole(ROLE_ADMIN, msg.sender);
    }

    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual 
        override(ERC165) 
        returns (bool) 
    {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function name()
        public
        view
        returns(string memory)
    {
        return _name;
    }

    function symbol()
        public
        view
        returns(string memory)
    {
        return _symbol;
    }

    function decimals()
        public
        pure
        returns(uint)
    {
        return 18;
    }

    function owner()
        public
        view
        returns(address)
    {
        return getRoleMember(ROLE_ADMIN, 0);
    }

    function totalSupply()
        public
        view
        returns(uint)
    {
        uint i;
        uint totalSupplyAmount;
        while(_totalSupply[++i] > 0) {
            totalSupplyAmount += _totalSupply[i];
        }
        return totalSupplyAmount;
    }

    function uri(uint id)
        public
        view
        virtual
        override
        returns(string memory)
    {
        return string(abi.encodePacked(_urlPrefix, id, ".json"));
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

    function adminSetURI(string memory newUrlPrefix)
        public
        onlyRole(ROLE_ADMIN)
    {
        _setURI(string(abi.encodePacked(newUrlPrefix, "{id}.json")));

        _urlPrefix = newUrlPrefix;
    }

    function adminUpdateNameAndSymbol(string memory newName, string memory newSymbol)
        public
        onlyRole(ROLE_ADMIN)
    {
        _name = newName;
        _symbol = newSymbol;
    }

    function adminSafeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) 
        public
        onlyRole(ROLE_ADMIN)
        executeCronJobs()
        checkForBots(msg.sender)
    {
        bytes memory data;
        _safeTransferFrom(from, to, id, amount, data);
    }
    
    function adminSafeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
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
        bytes memory data;
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function adminMint(
        address to,
        uint256 id,
        uint256 amount
    ) 
        public
        // TODO: enable on production
        /*onlyRole(ROLE_ADMIN)
        executeCronJobs()*/
    {
        bytes memory data;
        _mint(to, id, amount, data);
    }

    function adminMintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) 
        public
        // TODO: enable on production
        /*onlyRole(ROLE_ADMIN)
        executeCronJobs()*/
    {
        bytes memory data;
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