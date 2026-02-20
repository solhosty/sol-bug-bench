// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VulnerableMintToken
 * @dev ERC20 token with mint functionality that has an intentional reentrancy vulnerability
 *
 * VULNERABILITY: The mintWithdraw function performs an external call before updating state,
 * allowing reentrancy attacks. An attacker can recursively call mintWithdraw to drain
 * the contract's ETH balance and mint unlimited tokens.
 */
contract VulnerableMintToken is ERC20, Ownable {
    event TokensMinted(address indexed to, uint256 amount);
    event ETHDeposited(address indexed from, uint256 amount);

    constructor() ERC20("Vulnerable Mint Token", "VMT") Ownable(msg.sender) {}

    /**
     * @dev Allows anyone to deposit ETH into the contract
     */
    function depositETH() external payable {
        require(msg.value > 0, "Must send ETH");
        emit ETHDeposited(msg.sender, msg.value);
    }

    /**
     * @dev Owner can deposit ETH directly
     */
    receive() external payable {
        emit ETHDeposited(msg.sender, msg.value);
    }

    /**
     * @dev Mints tokens and sends ETH to caller
     * @param amount Number of tokens to mint (must be between 1 and 3)
     *
     * VULNERABLE_REENTRANCY: External call to msg.sender before state is finalized.
     * The _mint call updates balances, but the external call happens before the function
     * completes, allowing the caller to re-enter and mint more tokens while receiving ETH.
     */
    function mintWithdraw(uint256 amount) external {
        require(amount >= 1 && amount <= 3, "Invalid mint amount");
        _mint(msg.sender, amount);
        emit TokensMinted(msg.sender, amount);
        
        // VULNERABLE_REENTRANCY: External call before state update
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success, "ETH transfer failed");
    }

    /**
     * @dev Get contract ETH balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
