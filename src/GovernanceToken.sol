// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";

contract GovernanceToken is ERC20 {
    mapping(address => bool) public blacklisted;

    constructor() ERC20("Governance Token", "GOV", 18) {
        _mint(msg.sender, 1_000_000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function updateUserStatus(address user, bool isBlacklisted) external {
        blacklisted[user] = isBlacklisted;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        view
        override
    {
        amount;
        if (from != address(0) && blacklisted[from]) {
            revert("Sender is blacklisted");
        }
        if (to != address(0) && blacklisted[to]) {
            revert("Recipient is blacklisted");
        }
    }
}
