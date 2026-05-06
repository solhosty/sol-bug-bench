// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/// @title SimpleWithdraw
/// @notice Minimal ETH balance tracking contract with user-controlled withdrawals.
contract SimpleWithdraw {
    /// @notice Per-user ETH deposits tracked by sender address.
    mapping(address => uint256) public balances;

    /// @notice Accept direct ETH transfers and credit the sender's balance.
    receive() external payable {
        balances[msg.sender] += msg.value;
    }

    /// @notice Deposit ETH using an explicit function call.
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    /// @notice Withdraw a specific amount of ETH from the caller's tracked balance.
    /// @param amount Amount of ETH to withdraw in wei.
    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // Update state before the external call (checks-effects-interactions).
        balances[msg.sender] -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }

    /// @notice Read the tracked ETH balance for an account.
    /// @param account Address to query.
    /// @return Tracked balance in wei.
    function getBalance(address account) external view returns (uint256) {
        return balances[account];
    }
}
