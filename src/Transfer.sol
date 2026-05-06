// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Transfer {
    event EthSent(address indexed from, address indexed to, uint256 amount);
    event TokenSent(
        address indexed token,
        address indexed from,
        address indexed to,
        uint256 amount
    );

    function sendEth(address payable to) external payable {
        require(msg.value > 0, "Amount must be greater than 0");
        require(to != address(0), "Invalid recipient");

        (bool success,) = to.call{value: msg.value}("");
        require(success, "ETH transfer failed");

        emit EthSent(msg.sender, to, msg.value);
    }

    function sendToken(IERC20 token, address to, uint256 amount) external {
        require(address(token) != address(0), "Invalid token");
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be greater than 0");

        bool success = token.transferFrom(msg.sender, to, amount);
        require(success, "Token transfer failed");

        emit TokenSent(address(token), msg.sender, to, amount);
    }
}
