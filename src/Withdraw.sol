// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Withdraw
 * @notice Simple ETH escrow allowing users to deposit and withdraw their own funds.
 * @dev Each user has an isolated balance bucket tracked in storage.
 * Deposits increase the sender's bucket and withdrawals follow
 * checks-effects-interactions to reduce reentrancy risk.
 */
contract Withdraw {
    error InsufficientBalance();
    error TransferFailed();

    /// @notice Emitted when a user deposits ETH into escrow.
    event Deposited(address indexed user, uint256 amount);
    /// @notice Emitted when a user withdraws ETH from escrow.
    event Withdrawn(address indexed user, uint256 amount);

    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        if (balances[msg.sender] < amount) {
            revert InsufficientBalance();
        }

        balances[msg.sender] -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert TransferFailed();
        }

        emit Withdrawn(msg.sender, amount);
    }
}
