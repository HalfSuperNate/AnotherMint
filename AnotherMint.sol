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
import {LibPRNG} from "solady/src/utils/LibPRNG.sol";
import {LibString} from "solady/src/utils/LibString.sol";
import {Base64} from "solady/src/utils/Base64.sol";

/// @author developer's github https://github.com/HalfSuperNate
contract AnotherMint is ERC721Holder, ERC1155Holder, ReentrancyGuard, Admins{

    mapping(uint256 => address) public batchAddress;
    mapping(address => uint256) public addressBatch;
    mapping(uint256 => bool) public paused;
    mapping(uint256 => uint256) public cost;

    // Struct to represent ERC20 token and its balance
    struct ERC20Token {
        address tokenAddress;
        uint256 balance;
        uint8 decimals;
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
        uint256 tokenType;
        ERC20Token erc20;
        ERC721Token erc721;
        ERC1155Token erc1155;
        bytes32 root;
        bool randomize;
        uint256 minted;
    }

    TokenBatch[] public tokenBatchID;

    address public vault;

    error InvalidID();
    error ErrorMintTxPrice();
    error OverMintLimit();
    error Paused();
    error NotListed();

    constructor() Admins(msg.sender) {
        init();
    }

    /**
     * @dev Allow admins to set paused state for a Batch.
     * @param _ID The ID of the Batch to edit.
     * @param _state Paused state to set.
     */
    function setPaused(uint256 _ID, bool _state) public onlyAdmins {
        if (_ID < tokenBatchID.length){
            paused[_ID] = _state;
        } else {
            revert InvalidID();
        }
    }

    /**
     * @dev Allow admins to set Batch root.
     * @param _ID The ID of the Batch to edit.
     * @param _root Root to set.
     */
    function setRoot(uint256 _ID, bytes32 _root) public onlyAdmins {
        if (_ID < tokenBatchID.length){
            tokenBatchID[_ID].root = _root;
        } else {
            revert InvalidID();
        }
    }

    function createBatch(uint256 _tokenType, address _tokenAddress, uint256[] calldata _tokenIDs, uint256[] calldata _amounts, bool _isRandom) public onlyAdmins {
        require(_tokenType == 20 || _tokenType == 721 || _tokenType == 1155, "Invalid Type");
        uint256 newBatchID = tokenBatchID.length;
        batchAddress[newBatchID] = _tokenAddress; // set to new address
        addressBatch[_tokenAddress] = newBatchID; // set to new batch
        paused[newBatchID] = true; // Default is paused

        // Defaults
        ERC20Token memory newERC20 = tokenBatchID[0].erc20;
        ERC721Token memory newERC721 = tokenBatchID[0].erc721;
        ERC1155Token memory newERC1155 = tokenBatchID[0].erc1155;

        if (_tokenType == 20) {
            // Set ERC20
            newERC20.tokenAddress = _tokenAddress;
            newERC20.balance = _amounts[0];
            newERC20.decimals = uint8(_amounts[1]);
            // Transfer tokens to this contract
            IERC20(_tokenAddress).transferFrom(msg.sender, address(this), (_amounts[0]));
        }

        if (_tokenType == 721) {
            // Set ERC721
            newERC721.tokenAddress = _tokenAddress;
            newERC721.tokenIDs = _tokenIDs;
            // Transfer tokens to this contract
            for (uint256 i = 0; i < _tokenIDs.length; i++) {
                IERC721(_tokenAddress).transferFrom(msg.sender, address(this), _tokenIDs[i]);
            }
        }

        if (_tokenType == 1155) {
            // Set ERC1155
            newERC1155.tokenAddress = _tokenAddress;
            newERC1155.tokenIDs = _tokenIDs;
            newERC1155.balances = _amounts;
            // Transfer batch of tokens to this contract
            IERC1155(_tokenAddress).safeBatchTransferFrom(msg.sender, address(this), _tokenIDs, _amounts, "");
        }

        // Build new batch
        TokenBatch memory newBatch = TokenBatch({
            tokenType: _tokenType,
            erc20: newERC20,
            erc721: newERC721,
            erc1155: newERC1155,
            root: 0x0000000000000000000000000000000000000000000000000000000000000000,
            randomize: _isRandom,
            minted: 0
        });

        // Add the new batch to list
        tokenBatchID.push(newBatch);
    }

    /**
     * @dev Admin can set the new cost in WEI.
     * 1 ETH = 10^18 WEI
     * Note: Use https://etherscan.io/unitconverter for ETH to WEI conversions.
     */
    function setCost(uint256 _ID, uint256 _newCost) public onlyAdmins {
        cost[_ID] = _newCost;
    }

    /**
     * @dev Allows users to mint an amount of tokens.
     * @param _amount The amount of tokens to mint.
     */
    function mint(bytes32[] memory proof, address _to, uint256 _ID, uint256 _amount) external payable nonReentrant {
        if (!checkIfAdmin()) {
            if (paused[_ID]) revert Paused();
            if (overLimit(_ID, _amount)) revert OverMintLimit();
            if (msg.value < cost[_ID] * _amount) revert ErrorMintTxPrice(); // ❌ adjust for ERC20 decimals

            if (tokenBatchID[_ID].root != tokenBatchID[0].root) {
                if (!verifyUser(proof, _ID, msg.sender)) revert NotListed();
            }
        }
        // simulate another mint for that batch here ⭕️
        if (tokenBatchID[_ID].tokenType == 20) {
            tokenBatchID[_ID].erc20.balance -= _amount;
            // Transfer tokens to minter
            IERC20(tokenBatchID[_ID].erc20.tokenAddress).transferFrom(address(this), _to, _amount);
        }

        if (tokenBatchID[_ID].tokenType == 721) {
            // Transfer tokens to minter
            if (!tokenBatchID[_ID].randomize) {
                // not random, mint from end of list and pop last token after transfer
                for (uint256 i = 0; i < _amount; i++) {
                    // transfer the last element from the tokenIDs array then remove it
                    IERC721(tokenBatchID[_ID].erc721.tokenAddress).transferFrom(address(this), _to, tokenBatchID[_ID].erc721.tokenIDs[tokenBatchID[_ID].erc721.tokenIDs.length - 1]);
                    tokenBatchID[_ID].erc721.tokenIDs.pop();
                }
            } else {
                //randomize the end of the array, mint from end of list and pop last token after transfer
                for (uint256 i = 0; i < _amount; i++) {
                    uint256 random = uint(getRandom(i, 0, int(tokenBatchID[_ID].erc721.tokenIDs.length - 1)));
                    (tokenBatchID[_ID].erc721.tokenIDs[random], tokenBatchID[_ID].erc721.tokenIDs[tokenBatchID[_ID].erc721.tokenIDs.length - 1]) = (tokenBatchID[_ID].erc721.tokenIDs[tokenBatchID[_ID].erc721.tokenIDs.length - 1], tokenBatchID[_ID].erc721.tokenIDs[random]);
                    // transfer the last element from the tokenIDs array then remove it
                    IERC721(tokenBatchID[_ID].erc721.tokenAddress).transferFrom(address(this), _to, tokenBatchID[_ID].erc721.tokenIDs[tokenBatchID[_ID].erc721.tokenIDs.length - 1]);
                    tokenBatchID[_ID].erc721.tokenIDs.pop();
                }
            }
        }

        if (tokenBatchID[_ID].tokenType == 1155) {
            uint256[] memory _tokenIDs = new uint256[](_amount);
            uint256[] memory _amounts = new uint256[](_amount);
            // Transfer batch of tokens to minter
            if (!tokenBatchID[_ID].randomize) {
                // not random, mint from end of list and pop last token after transfer
                for (uint256 i = 0; i < _amount; i++) {
                    // push the last element from the tokenIDs array then remove it
                    _tokenIDs[i] = tokenBatchID[_ID].erc1155.tokenIDs[tokenBatchID[_ID].erc1155.tokenIDs.length - 1];
                    _amounts[i] = tokenBatchID[_ID].erc1155.balances[tokenBatchID[_ID].erc1155.balances.length - 1];
                    tokenBatchID[_ID].erc1155.tokenIDs.pop();
                    tokenBatchID[_ID].erc1155.balances.pop();
                }
            } else {
                //randomize the end of the array, mint from end of list and pop last token after transfer
                for (uint256 i = 0; i < _amount; i++) {
                    uint256 random = uint(getRandom(i, 0, int(tokenBatchID[_ID].erc1155.tokenIDs.length - 1)));
                    (tokenBatchID[_ID].erc1155.tokenIDs[random], tokenBatchID[_ID].erc1155.tokenIDs[tokenBatchID[_ID].erc1155.tokenIDs.length - 1]) = (tokenBatchID[_ID].erc1155.tokenIDs[tokenBatchID[_ID].erc1155.tokenIDs.length - 1], tokenBatchID[_ID].erc1155.tokenIDs[random]);
                    (tokenBatchID[_ID].erc1155.balances[random], tokenBatchID[_ID].erc1155.balances[tokenBatchID[_ID].erc1155.balances.length - 1]) = (tokenBatchID[_ID].erc1155.balances[tokenBatchID[_ID].erc1155.balances.length - 1], tokenBatchID[_ID].erc1155.balances[random]);
                    // push the last element from the tokenIDs array then remove it
                    _tokenIDs[i] = tokenBatchID[_ID].erc1155.tokenIDs[tokenBatchID[_ID].erc1155.tokenIDs.length - 1];
                    _amounts[i] = tokenBatchID[_ID].erc1155.balances[tokenBatchID[_ID].erc1155.balances.length - 1];
                    tokenBatchID[_ID].erc1155.tokenIDs.pop();
                    tokenBatchID[_ID].erc1155.balances.pop();
                }
            }
            IERC1155(tokenBatchID[_ID].erc1155.tokenAddress).safeBatchTransferFrom(address(this), msg.sender, _tokenIDs, _amounts, "");
        }

        tokenBatchID[_ID].minted += _amount;
    }

    /**
     * @dev Verify if user is listed.
     * @param proof bytes32 array for proof.
     * @param _ID Batch ID to get root.
     * @param _user Address to check.
     */
    function verifyUser(bytes32[] memory proof, uint256 _ID, address _user) public view returns (bool) {
        if (proof.length != 0){
            if (MerkleProof.verify(proof, tokenBatchID[_ID].root, keccak256(abi.encodePacked(_user)))){
                return (true);
            }
        }
        return (false);
    }

    function overLimit(uint256 _ID, uint256 _amount) public view returns(bool) {
        if (tokenBatchID[_ID].tokenType == 20) {
            if (_amount > tokenBatchID[_ID].erc20.balance) return true;
        }
        if (tokenBatchID[_ID].tokenType == 721) {
            if (_amount > (tokenBatchID[_ID].erc721.tokenIDs.length - 1)) return true;
        }
        if (tokenBatchID[_ID].tokenType == 1155) {
            if (_amount > (tokenBatchID[_ID].erc1155.tokenIDs.length - 1)) return true;
        }
        return false;
    }

    /**
    @dev Returns a random number in the range of min and max.
    @param _seed The random user input number.
    @param _min The min random result.
    @param _max The max random result.
    @return A random selected number within the inclusive range.
    */
    function getRandom(uint _seed, int _min, int _max) public view returns (int256){
        if(_min == _max) return _min;
        uint random = uint(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            msg.sender,
            _seed,
            _min,
            _max,
            isEvenTimestamp())
        )) % 100;

        LibPRNG.PRNG memory newPRNG = LibPRNG.PRNG({
            state: random
        });
        int _newPRNG = int(LibPRNG.uniform(newPRNG,101));

        int _dif = (_max - _min);
        int _calcRandom = ((_dif * _newPRNG) / 100);

        return _min + _calcRandom;
    }

    function isEvenTimestamp() public view returns (bool) {
        return block.timestamp % 2 == 0;
    }

    // Initialize empty data for ERC20, ERC721, and ERC1155 tokens then push an empty Batch
    function init() internal {
        require(tokenBatchID.length == 0);
        ERC20Token memory newToken = ERC20Token({
            tokenAddress: address(0),
            balance: 0,
            decimals: 18
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
            tokenType: 0,
            erc20: newToken,
            erc721: _newToken,
            erc1155: __newToken,
            root: 0x0000000000000000000000000000000000000000000000000000000000000000,
            randomize: false,
            minted: 0
        });

        tokenBatchID.push(newBatch);
        // batchAddress[0] = address(0); // defaulted to 0 address
        // addressBatch[address(0)] = 0; // defaulted to 0 batch
        vault = msg.sender;
    }

    /**
     * @dev Allow admins to set a new vault address.
     * @param _newVault New vault to set.
     */
    function setVault(address _newVault) public onlyAdmins {
        require(vault != address(0), "Vault Cannot Be 0");
        vault = _newVault;
    }

    /**
     * @dev Pull funds to the vault address.
     */
    function withdraw() external {
        require(vault != address(0), "Vault Cannot Be 0");
        (bool success, ) = payable(vault).call{ value: address(this).balance } ("");
        require(success);
    }
}
