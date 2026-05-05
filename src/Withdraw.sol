// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Withdraw
 * @dev Minimal ETH escrow contract with per-user balances.
 */
contract Withdraw {
    error InsufficientBalance();
    error TransferFailed();

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    mapping(address => uint256) public balances;

    /**
     * @dev Deposits ETH into the sender's balance.
     */
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev Withdraws ETH from the sender's balance.
     * @param amount The amount of ETH to withdraw.
     */
    function withdraw(uint256 amount) external {
        if (balances[msg.sender] < amount) {
            revert InsufficientBalance();
        }

        balances[msg.sender] -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) {
            revert TransferFailed();
        }

        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @dev Returns the ETH balance tracked for a user.
     * @param user The address to query.
     * @return The tracked ETH balance for the user.
     */
    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }
}
