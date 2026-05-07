// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title SimpleMintTokenV3
 * @dev Minimal ERC20 token with owner-restricted minting.
 */
contract SimpleMintTokenV3 is ERC20, Ownable {
    /**
     * @dev Initializes token metadata and sets the owner.
     * @param tokenName The token name.
     * @param tokenSymbol The token symbol.
     */
    constructor(
        string memory tokenName,
        string memory tokenSymbol
    ) ERC20(tokenName, tokenSymbol) Ownable(msg.sender) {}

    /**
     * @dev Mints tokens to a recipient.
     * @param to The recipient address.
     * @param value The token amount.
     */
    function mint(address to, uint256 value) external onlyOwner {
        _mint(to, value);
    }
}
