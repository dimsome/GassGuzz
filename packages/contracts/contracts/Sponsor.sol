// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

import {IERC6551Registry} from "./interfaces/IERC6551Registry.sol";
import {IERC6551Account} from "./interfaces/IERC6551Account.sol";

contract Sponsor is CCIPReceiver, ERC721 {
    struct DepositData {
        address depositor;
        uint256 amount;
    }

    struct CallData {
        bytes32 hash;
        bytes signature;
        bytes executionData;
        uint256 maxGas;
        bytes gasSignature;
    }

    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender // The address of the sender from the source chain.
    );

    // Mapping to keep track of whitelisted source chains.
    mapping(uint64 => bool) public whitelistedSourceChains;

    // Mapping to keep track of whitelisted senders.
    mapping(address => bool) public whitelistedSenders;

    // Mapping to keep track of the balances of the users
    mapping(uint256 => uint256) public allowances;

    bytes32 private lastReceivedMessageId; // Store the last received messageId.
    string private lastReceivedText; // Store the last received text.
    string public baseTokenURI;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    // ERC6551-related state variables
    IERC6551Registry public immutable registry;
    address payable public immutable implementation;
    uint256 public immutable registryChainId;
    uint256 public immutable salt;

    constructor(
        address _router,
        uint64 _whitelistSourceChain,
        address _whitelistSender,
        string memory _initBaseURI,
        string memory _name,
        string memory _symbol,
        address registry_,
        address payable implementation_,
        uint256 registryChainId_,
        uint256 salt_
    ) CCIPReceiver(_router) ERC721(_name, _symbol) {
        // Add the source chain to the whitelist.
        whitelistedSourceChains[_whitelistSourceChain] = true;
        // Add the sender to the whitelist.
        whitelistedSenders[_whitelistSender] = true;
        baseTokenURI = _initBaseURI;

        // ERC6551-related state variables
        registry = IERC6551Registry(registry_);
        implementation = implementation_;
        registryChainId = registryChainId_;
        salt = salt_;
    }

    /// @dev Modifier that checks if the chain with the given sourceChainSelector is whitelisted.
    /// @param _sourceChainSelector The selector of the destination chain.
    modifier onlyWhitelistedSourceChain(uint64 _sourceChainSelector) {
        require(
            whitelistedSourceChains[_sourceChainSelector],
            "SourceChainNotWhitelisted"
        );
        _;
    }

    /// @dev Modifier that checks if the sender is whitelisted.
    /// @param _sender The address of the sender.
    modifier onlyWhitelistedSenders(address _sender) {
        require(whitelistedSenders[_sender], "SenderNotWhitelisted");
        _;
    }

    function receiveDeposit() public {
        // Receive message via CCIP from the Depositor contract
        // Set the MAX allowance for the Contract
        // Mint ERC721 with ERC6551 to receiver
    }

    function settle() public {
        // Sum the total amount of spend ETH as GAS
        // Send result to the Depositor contract
    }

    /// handle a received message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
        onlyWhitelistedSourceChain(any2EvmMessage.sourceChainSelector) // Make sure source chain is whitelisted
        onlyWhitelistedSenders(abi.decode(any2EvmMessage.sender, (address))) // Make sure the sender is whitelisted
    {
        lastReceivedMessageId = any2EvmMessage.messageId; // fetch the messageId
        lastReceivedText = abi.decode(any2EvmMessage.data, (string)); // abi-decoding of the sent text

        // Decode the data from the message
        DepositData memory decodedData = abi.decode(
            any2EvmMessage.data,
            (DepositData)
        );
        address sender = decodedData.depositor;

        // Mint ERC721 with ERC6551 to receiver
        (uint256 tokenId, ) = _mintToken(sender);

        // Set allowance for tokenId
        allowances[tokenId] = decodedData.amount;

        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector, // fetch the source chain identifier (aka selector)
            sender
        );
    }

    function _mintToken(
        address _to
    ) internal returns (uint256 tokenId, address newAccount) {
        tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(_to, tokenId);

        // Initialize the Pack and create the account
        newAccount = registry.createAccount(
            implementation,
            registryChainId,
            address(this),
            tokenId,
            salt,
            "" // initData
        );
    }

    function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory result) {
        CallData memory callData = abi.decode(data, (CallData));
        // Only callable with a valid singature from owner

        bytes4 magicValue = IERC6551Account(implementation).isValidSignature(
            callData.hash,
            callData.signature
        );
        require(
            magicValue == IERC1271.isValidSignature.selector,
            "Invalid signature"
        );

        // Check singature for maxGas
        magicValue = IERC6551Account(implementation).isValidSignature(
            keccak256(abi.encodePacked(callData.maxGas)),
            callData.gasSignature
        );
        require(
            magicValue == IERC1271.isValidSignature.selector,
            "Invalid signature"
        );

        IERC6551Account(implementation).executeCall(
            to,
            value,
            callData.executionData
        );

        // Transfer the maxGas to the sender
        payable(msg.sender).transfer(callData.maxGas);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public pure virtual override(ERC721, CCIPReceiver) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
