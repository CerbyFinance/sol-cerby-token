// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.11;

import "./openzeppelin/token/ERC1155/ERC1155.sol";


contract CerbySwapLP1155V1 is ERC1155 {

    constructor()
        ERC1155("")
    {

    }

    function setApprovalForAll(address operator, bool approved) 
        public 
        virtual 
        override 
    {
        _setApprovalForAll(_msgSender(), operator, approved);
    }
}