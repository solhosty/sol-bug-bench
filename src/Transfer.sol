// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Transfer is Ownable {
    mapping(address => uint256) public ethBalances;

    event ETHDeposited(address indexed user, uint256 amount);
    event ETHWithdrawn(address indexed user, uint256 amount);
    event ETHTransferred(address indexed from, address indexed to, uint256 amount);
    event ERC20Transferred(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 amount
    );

    constructor() Ownable(msg.sender) {}

    function deposit() external payable {
        require(msg.value > 0, "Zero amount");
        ethBalances[msg.sender] += msg.value;
        emit ETHDeposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        uint256 balance = ethBalances[msg.sender];
        require(amount > 0, "Zero amount");
        require(balance >= amount, "Insufficient balance");

        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH transfer failed");

        ethBalances[msg.sender] = balance - amount;
        emit ETHWithdrawn(msg.sender, amount);
    }

    function transferETH(address to, uint256 amount) external {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Zero amount");
        require(ethBalances[msg.sender] >= amount, "Insufficient balance");

        ethBalances[msg.sender] -= amount;
        ethBalances[to] += amount;

        emit ETHTransferred(msg.sender, to, amount);
    }

    function transferERC20(
        IERC20 token,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(address(token) != address(0), "Invalid token");
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Zero amount");

        token.transfer(to, amount);
        emit ERC20Transferred(address(token), address(this), to, amount);
    }

    function transferERC20From(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) external {
        require(address(token) != address(0), "Invalid token");
        require(from != address(0), "Invalid sender");
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Zero amount");

        token.transferFrom(from, to, amount);
        emit ERC20Transferred(address(token), from, to, amount);
    }
}
