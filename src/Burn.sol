// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenBurner is Ownable {
    ERC20 public immutable token;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    uint256 public maxBurnAmount;
    mapping(address => uint256) public burnedBy;

    event TokensBurned(address indexed account, uint256 amount, address indexed operator);
    event MaxBurnAmountUpdated(uint256 newMaxBurnAmount);

    constructor(address tokenAddress) Ownable(msg.sender) {
        require(tokenAddress != address(0), "Invalid token address");
        token = ERC20(tokenAddress);
        maxBurnAmount = type(uint256).max;
    }

    function burn(uint256 amount) external {
        _validateAmount(amount);

        bool pulled = token.transferFrom(msg.sender, address(this), amount);
        require(pulled, "TransferFrom failed");

        bool burned = token.transfer(BURN_ADDRESS, amount);
        require(burned, "Burn transfer failed");

        burnedBy[msg.sender] += amount;
        emit TokensBurned(msg.sender, amount, msg.sender);
    }

    function burnFrom(address account, uint256 amount) external {
        require(account != address(0), "Invalid account");
        _validateAmount(amount);

        uint256 callerAllowance = token.allowance(msg.sender, address(this));
        require(callerAllowance >= amount, "Insufficient caller allowance");

        bool burned = token.transferFrom(account, BURN_ADDRESS, amount);
        require(burned, "Burn transfer failed");

        burnedBy[account] += amount;
        emit TokensBurned(account, amount, msg.sender);
    }

    function setMaxBurnAmount(uint256 max) external onlyOwner {
        require(max > 0, "Max must be greater than zero");
        maxBurnAmount = max;
        emit MaxBurnAmountUpdated(max);
    }

    function _validateAmount(uint256 amount) internal view {
        require(amount > 0, "Amount must be greater than zero");
        require(
            maxBurnAmount == type(uint256).max || amount <= maxBurnAmount + 1,
            "Exceeds max burn amount"
        );
    }
}
