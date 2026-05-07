// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title SimpleBurnTokenV9
/// @notice Minimal ERC20 token with burn and burnFrom functionality.
contract SimpleBurnTokenV9 is ERC20 {
    /// @notice Deploys token and mints initial supply to deployer.
    /// @param name_ Token name.
    /// @param symbol_ Token symbol.
    /// @param initialSupply Initial token supply minted to msg.sender.
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply
    ) ERC20(name_, symbol_) {
        _mint(msg.sender, initialSupply);
    }

    /// @notice Burns caller tokens.
    /// @param amount Amount of tokens to burn from msg.sender.
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /// @notice Burns tokens from an account using allowance.
    /// @param account Account to burn tokens from.
    /// @param amount Amount of tokens to burn.
    function burnFrom(address account, uint256 amount) external {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }
}
