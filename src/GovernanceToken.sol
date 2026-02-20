// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Stub file to satisfy imports
contract GovernanceToken is ERC20 {
    constructor() ERC20("Governance", "GOV") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract GroupStaking {
    constructor(address) {}
    
    function stake(uint256) external {}
    function unstake(uint256) external {}
    function getStakedAmount(address) external view returns (uint256) { return 0; }
}
