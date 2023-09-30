// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

contract Depositor {
    using SafeERC20 for IERC20;

    IRouterClient public immutable router;
    uint64 public immutable destinationChain;
    IERC20 public immutable stETH;
    address public immutable l2ReceiverContract;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public lastPrice;

    // Event emitted when a message is sent to another chain.
    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the CCIP message.
    );

    struct DepositData {
        address depositor;
        uint256 amount;
    }

    constructor(
        address _stETH,
        address _router,
        uint64 _destinationChain,
        address _receiver
    ) {
        stETH = IERC20(_stETH);
        router = IRouterClient(_router);
        destinationChain = _destinationChain;
        l2ReceiverContract = _receiver;
    }

    function deposit(uint256 amount) public returns (bytes32 messageId) {
        // Deposit an ERC20 token (stETH) into the contract
        require(amount > 0, "Depositor: amount must be greater than 0");
        // 1. TransferFrom the ERC20 token to the contract
        stETH.safeTransferFrom(msg.sender, address(this), amount);
        // 2. Update the balance of the user
        balances[msg.sender] += amount;
        // 3. Update the last price of the user
        lastPrice[msg.sender] = getPrice();

        // create data for the message
        DepositData memory data = DepositData({
            depositor: msg.sender,
            amount: amount
        });

        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            l2ReceiverContract,
            data,
            address(0)
        );

        uint256 fees = router.getFee(destinationChain, evm2AnyMessage);

        require(
            fees <= address(this).balance,
            "Depositor: Insufficient balance to cover fees"
        );

        // Send message via CCIP to the Sponsor contract
        messageId = router.ccipSend(destinationChain, evm2AnyMessage);

        emit MessageSent(
            messageId,
            destinationChain,
            l2ReceiverContract,
            address(0),
            fees
        );
    }

    function _buildCCIPMessage(
        address _receiver,
        DepositData memory _data,
        address _feeTokenAddress
    ) internal pure returns (Client.EVM2AnyMessage memory) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver), // ABI-encoded receiver address
            data: abi.encode(_data), // ABI-encoded string
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array aas no tokens are transferred
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit and non-strict sequencing mode
                Client.EVMExtraArgsV1({gasLimit: 200_000, strict: false})
            ),
            // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
            feeToken: _feeTokenAddress
        });
        return evm2AnyMessage;
    }

    function settle() public {
        // Update the price since last time deposited
        // Calculate the amount of stETH to send back to the user
    }

    function getPrice() public view returns (uint256) {
        // Get the current price of stETH
        return 1e18;
    }
}
