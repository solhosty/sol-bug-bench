// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title NewToken
/// @notice Minimal ERC20 token used for benchmark and testing scenarios.
contract NewToken is ERC20 {
    /// @param initialSupply Amount of tokens minted to the deployer at deployment.
    constructor(uint256 initialSupply) ERC20("NewToken", "NTK") {
        _mint(msg.sender, initialSupply);
    }

    /// @notice Mints new tokens to the provided recipient.
    /// @dev Intentionally permissionless for minimal test coverage.
    /// @param to Recipient address for minted tokens.
    /// @param amount Amount of tokens to mint.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
