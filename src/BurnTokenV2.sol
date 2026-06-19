// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BurnTokenV2 is ERC20 {
    /**
     * @notice Deploys the token and mints the initial supply to the deployer.
     * @param name_ Token name.
     * @param symbol_ Token symbol.
     * @param initialSupply Initial token supply minted to msg.sender.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply
    ) ERC20(name_, symbol_) {
        _mint(msg.sender, initialSupply);
    }

    /**
     * @notice Burns tokens from the caller.
     * @param amount Amount of tokens to burn.
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @notice Burns tokens from an account after spending allowance.
     * @param account Address whose tokens are burned.
     * @param amount Amount of tokens to burn.
     */
    function burnFrom(address account, uint256 amount) external {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }
}
