// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Stub file to satisfy imports
contract StableCoin is ERC20 {
    constructor() ERC20("StableCoin", "STABLE") {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TokenStreamer {
    constructor(StableCoin) {}
}
