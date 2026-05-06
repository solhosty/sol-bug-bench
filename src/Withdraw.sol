// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

contract Withdraw {
    mapping(address => uint256) public balances;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    function deposit() external payable {
        require(msg.value > 0, "Amount must be greater than 0");

        balances[msg.sender] += msg.value;

        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");

        uint256 balance = balances[msg.sender];
        require(balance >= amount, "Insufficient balance");

        balances[msg.sender] = balance - amount;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }
}
