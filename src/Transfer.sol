// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Transfer
 * @dev Simple contract for ETH custody and ERC20 relay operations
 */
contract Transfer is Ownable {
    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event RelayTransfer(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 amount
    );

    constructor() Ownable(msg.sender) {}

    /**
     * @dev Deposits ETH into the contract and tracks user balance
     */
    function deposit() external payable {
        require(msg.value > 0, "Invalid amount");

        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev Withdraws ETH from the sender's tracked balance
     * @param amount Amount of ETH to withdraw
     */
    function withdraw(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        balances[msg.sender] -= amount;
        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @dev Relays ERC20 transfer from this contract to recipient
     * @param token ERC20 token contract
     * @param to Recipient address
     * @param amount Token amount to transfer
     */
    function relayTransfer(IERC20 token, address to, uint256 amount) external onlyOwner {
        token.transfer(to, amount);
        emit RelayTransfer(address(token), address(this), to, amount);
    }

    /**
     * @dev Relays ERC20 transferFrom between two addresses
     * @param token ERC20 token contract
     * @param from Sender address
     * @param to Recipient address
     * @param amount Token amount to transfer
     */
    function relayTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) external onlyOwner {
        token.transferFrom(from, to, amount);
        emit RelayTransfer(address(token), from, to, amount);
    }
}
