// SPDX-License-Identifier: MIT
pragma solidity ^ 0.8.23;

import {Admins} from "./Admins.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {LibString} from "solady/src/utils/LibString.sol";
import {Base64} from "solady/src/utils/Base64.sol";

/// @author developer's github https://github.com/HalfSuperNate
contract AnotherMint is ERC721Holder, ERC1155Holder, ReentrancyGuard, Admins{

    mapping(uint256 => address) public batchAddress;
    mapping(address => uint256) public addressBatch;

    // Struct to represent ERC20 token and its balance
    struct ERC20Token {
        address tokenAddress;
        uint256 balance;
    }

    // Struct to represent ERC721 token and its tokens
    struct ERC721Token {
        address tokenAddress;
        uint256[] tokenIDs;
    }

    // Struct to represent ERC1155 token and its tokens
    struct ERC1155Token {
        address tokenAddress;
        uint256[] tokenIDs;
        uint256[] balances;
    }

    // Struct to represent a token batch
    struct TokenBatch {
        ERC20Token erc20;
        ERC721Token erc721;
        ERC1155Token erc1155;
        bytes32 root;
        bool randomize;
    }

    TokenBatch[] public tokenBatchID;

    address public vault;

    constructor() Admins(msg.sender) {
        initTokenBundles();
    }

    /**
     * @dev Allow admins to set Batch root.
     * @param _ID The ID of the Batch to edit.
     * @param _root Root to set.
     */
    function setRoot(uint256 _ID, bytes32 _root) public onlyAdmins {
        require(_ID < tokenBatchID.length, "Invalid ID");
        tokenBatchID[_ID].root = _root;
    }

    function createTokenBundles(uint256 _tokenType, address _tokenAddress, uint256[] calldata _tokenIDs, uint256[] calldata _amounts, bool _isRandom) public onlyAdmins {
        require(_tokenType == 20 || _tokenType == 721 || _tokenType == 1155, "Invalid Type");

        ERC20Token memory newERC20 = tokenBatchID[0].erc20;
        ERC721Token memory newERC721 = tokenBatchID[0].erc721;
        ERC1155Token memory new1155 = tokenBatchID[0].erc1155;

        if (_tokenType == 20) {
            
        }

        if (_tokenType == 721) {
            
        }

        if (_tokenType == 1155) {
            
        }

        TokenBatch memory newBatch = TokenBatch({
            erc20: newERC20,
            erc721: newERC721,
            erc1155: new1155,
            root: 0x0000000000000000000000000000000000000000000000000000000000000000,
            randomize: _isRandom
        });

        tokenBatchID.push(newBatch);
        // batchAddress[0] = address(0); // defaulted to 0 address
        // addressBatch[address(0)] = 0; // defaulted to 0 batch
        vault = msg.sender;
    }

    // Initialize empty data for ERC20, ERC721, and ERC1155 tokens then push an empty Batch
    function initTokenBundles() internal {
        require(tokenBatchID.length == 0);
        ERC20Token memory newToken = ERC20Token({
            tokenAddress: address(0),
            balance: 0
        });

        ERC721Token memory _newToken = ERC721Token({
            tokenAddress: address(0),
            tokenIDs: new uint256[](0)
        });

        ERC1155Token memory __newToken = ERC1155Token({
            tokenAddress: address(0),
            tokenIDs: new uint256[](0),
            balances: new uint256[](0)
        });

        TokenBatch memory newBatch = TokenBatch({
            erc20: newToken,
            erc721: _newToken,
            erc1155: __newToken,
            root: 0x0000000000000000000000000000000000000000000000000000000000000000,
            randomize: false
        });

        tokenBatchID.push(newBatch);
        // batchAddress[0] = address(0); // defaulted to 0 address
        // addressBatch[address(0)] = 0; // defaulted to 0 batch
        vault = msg.sender;
    }
}