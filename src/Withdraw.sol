// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Withdraw
 * @notice Stores user ETH deposits and allows users to withdraw their balance.
 * @dev Uses checks-effects-interactions in withdraw to reduce reentrancy risk.
 */
contract Withdraw {
    /**
     * @notice Emitted when a user deposits ETH.
     * @param user The account that made the deposit.
     * @param amount The amount of ETH deposited.
     */
    event Deposited(address indexed user, uint256 amount);

    /**
     * @notice Emitted when a user withdraws ETH.
     * @param user The account that made the withdrawal.
     * @param amount The amount of ETH withdrawn.
     */
    event Withdrawn(address indexed user, uint256 amount);

    /**
     * @notice Reverts when a user attempts to withdraw more than their balance.
     */
    error InsufficientBalance();

    /**
     * @notice Reverts when an ETH transfer fails.
     */
    error TransferFailed();

    /// @notice Tracks each user's deposited ETH balance.
    mapping(address => uint256) public balances;

    /**
     * @notice Deposits ETH into the contract.
     * @dev Increases the caller's tracked balance by msg.value.
     */
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @notice Withdraws ETH from the caller's deposited balance.
     * @dev Checks balance, updates state, then transfers ETH via low-level call.
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

        emit Withdrawn(msg.sender, amount);
    }
}
