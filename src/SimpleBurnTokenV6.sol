// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract SimpleBurnTokenV6 is ERC20Burnable {
    constructor() ERC20("Simple Burn Token V6", "SBTV6") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }
}
