// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";

contract StableCoin is ERC20 {
    event TokensMinted(address indexed to, uint256 amount);

    constructor() ERC20("StableCoin", "SC", 1) {
        _mint(msg.sender, 1_000_000 * 10 ** decimals);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }
}
