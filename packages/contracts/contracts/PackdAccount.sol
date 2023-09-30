// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import "./interfaces/IERC6551Account.sol";
import "./lib/ERC6551AccountLib.sol";

/// @title ERC6551 Registry implementation
/// @author https://etherscan.io/address/0x02101dfb77fde026414827fdc604ddaf224f0921#code
contract PackdAccount is IERC6551Account {
    uint256 public nonce;
    address public sponsor;

    receive() external payable {}

    struct CallData {
        bytes32 hash;
        bytes signature;
        bytes executionData;
    }

    constructor(address _sponsor) {
        sponsor = _sponsor;
    }

    function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory result) {
        // Only callable via Sponsor Contract
        require(msg.sender == sponsor, "Only callable via Sponsor Contract");

        ++nonce;

        emit TransactionExecuted(to, value, data);

        bool success;
        (success, result) = to.call{value: value}(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function token() external view returns (uint256, address, uint256) {
        return ERC6551AccountLib.token();
    }

    function owner() public view returns (address) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = this
            .token();
        require(chainId == block.chainid, "Wrong chainID");
        return IERC721(tokenContract).ownerOf(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return (interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC6551Account).interfaceId);
    }

    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) public view returns (bytes4 magicValue) {
        bool isValid = SignatureChecker.isValidSignatureNow(
            owner(),
            hash,
            signature
        );

        if (isValid) {
            return IERC1271.isValidSignature.selector;
        }

        return "";
    }
}
