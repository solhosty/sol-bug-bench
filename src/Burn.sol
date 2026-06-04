// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Burn is Ownable {
    IERC20 public immutable token;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    mapping(address => uint256) public depositedBalance;

    event Deposited(address indexed user, uint256 amount);
    event Burned(address indexed user, uint256 amount);
    event BurnedFrom(address indexed caller, address indexed from, uint256 amount);

    constructor(IERC20 token_) Ownable(msg.sender) {
        token = token_;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Zero amount");

        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        depositedBalance[msg.sender] += amount;
        emit Deposited(msg.sender, amount);
    }

    function burn(uint256 amount) external {
        require(amount > 0, "Zero amount");
        require(depositedBalance[msg.sender] >= amount, "Insufficient deposited balance");

        depositedBalance[msg.sender] -= amount;
        token.transfer(BURN_ADDRESS, amount);

        emit Burned(msg.sender, amount);
    }

    function burnFrom(address from, uint256 amount) external {
        require(from != address(0), "Invalid account");
        require(amount > 0, "Zero amount");
        require(depositedBalance[from] >= amount, "Insufficient deposited balance");

        depositedBalance[from] -= amount;
        token.transfer(BURN_ADDRESS, amount);

        emit BurnedFrom(msg.sender, from, amount);
    }
}
