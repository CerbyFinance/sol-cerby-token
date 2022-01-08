// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.11;


interface ICerbySwapLP1155V1 {

    function setApprovalForAll(address operator, bool approved) 
        external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) 
        external;
    
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) 
        external;

    function adminSafeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) 
        external;
    
    function adminSafeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) 
        external;

    function adminMint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) 
        external;

    function adminMintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) 
        external;

    function adminBurn(
        address from,
        uint256 id,
        uint256 amount
    ) 
        external;

    function adminBurnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) 
        external;

    function totalSupply(uint256 id) external view returns (uint256);

    /**
     * @dev Indicates whether any token exist with a given id, or not.
     */
    function exists(uint256 id) external view returns (bool);
}