// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.11;

import "./openzeppelin/access/AccessControlEnumerable.sol";


interface IMintableBurnableToken {
    function balanceOf(address account) external returns (uint);

    function mintByBridge(address to, uint256 amount) external;
    function burnByBridge(address from, uint256 amount) external;
}


contract CasperBridge is AccessControlEnumerable {

    event ProofOfMint(
        //bytes[40]  srcToken, // ? 
        bytes[40] destToken,
        bytes[40] srcCaller,
        bytes[40] destCaller,
        uint256   destAmount,
        bytes32   burnProofHash
    );

    event ApprovedBurnProof(bytes32 burnProofHash);

    enum States {
        DefaultValue,
        Burned,
        Approved,
        Executed
    }

    enum ChainType {
        Undefined, Evm, Casper, Solana, Radix 
    }

    address public _srcToken; // original format (20 bytes, or 32 bytes in case of casper)
    ChainType _srcChainType;

    // it's common storage for all chains (evm, casper, solana etc)
    mapping(bytes32 => States) public burnProofStorage;
    mapping(address => uint256) public currentNonce;

    constructor() {
        _srcToken = address(1);
        _srcChainType = ChainType.Evm;
    }

    function approveBurnProof(bytes32 proofHash) external {
        require(
            burnProofStorage[proofHash] == States.DefaultValue,
            "CCB: Already approved"
        );
        burnProofStorage[proofHash] = States.Approved;
        emit ApprovedBurnProof(proofHash);
    }

    function mintWithBurnProof(
        bytes[40] memory destToken,
        bytes[40] memory destCaller,
        bytes32   destBurnProofHash,
        uint256   destAmount,
        uint256   destNonce
    ) external {
        require(
            burnProofStorage[destBurnProofHash] == States.Approved,
            "CCB: Proof is not approved or already executed"
        );

        // get these field on our own chain

        // bytes[40] memory srcCaller = abi.encodePacked(msg.sender); // does not work
        // bytes[40] memory srcToken  = abi.encodePacked(_srcToken);

        address _srcCaller = msg.sender;
        bytes[40] memory srcCaller;
        assembly {
            mstore(
                add(
                    srcCaller,
                    40
                ),
                _srcCaller
            )
        }


        address __srcToken = _srcToken; // idk why, but it works only when reassigned
        bytes[40] memory srcToken;
        assembly {
            mstore(
                add(
                    srcToken,
                    40
                ),
                __srcToken // can't pass _srcToken for some reason
            )
        }


        
        uint8  srcChainType = uint8(_srcChainType);
        uint16 srcChainId   = uint16(block.chainid); 

        bytes memory packed = abi.encodePacked(
                abi.encode(srcCaller), abi.encode(destCaller),
                abi.encode(srcToken), abi.encode(destToken), 
                destAmount,
                srcChainType, srcChainId,
                destNonce
        );

        require(packed.length == 40 + 40 + 40 + 40 + 32 + 1 + 2 + 32, "package is invalid");

        bytes32 computedBurnProofHash = sha256(
            packed
        );

        require(computedBurnProofHash == destBurnProofHash, "CCB: Provided hash is invalid");

        burnProofStorage[destBurnProofHash] = States.Executed;

        IMintableBurnableToken(_srcToken).mintByBridge(msg.sender, destAmount);

        emit ProofOfMint(
            // srcToken,
            destToken,
            srcCaller,
            destCaller,
            destAmount,
            destBurnProofHash
        );
    }
}