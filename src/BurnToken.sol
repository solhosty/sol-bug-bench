// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BurnToken is ERC20 {
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);

    constructor() ERC20("Burn Token", "BURN") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    function burnFrom(address from, uint256 amount) external {
        _burn(from, amount);
        emit TokensBurned(from, amount);
    }
}

contract TokenVault {
    error InvalidAmount();
    error TransferFailed();

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event TokensDestroyed(address indexed caller, uint256 amount);

    BurnToken public immutable burnToken;
    mapping(address => uint256) public deposits;

    constructor(BurnToken burnToken_) {
        burnToken = burnToken_;
    }

    function deposit(uint256 amount) external {
        if (amount == 0) {
            revert InvalidAmount();
        }

        bool success = burnToken.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert TransferFailed();
        }

        deposits[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) {
            revert InvalidAmount();
        }

        deposits[msg.sender] -= amount;

        bool success = burnToken.transfer(msg.sender, amount);
        if (!success) {
            revert TransferFailed();
        }

        emit Withdrawal(msg.sender, amount);
    }

    function burnAll() external {
        uint256 totalVaultBalance = burnToken.balanceOf(address(this));
        burnToken.burn(totalVaultBalance);
        emit TokensDestroyed(msg.sender, totalVaultBalance);
    }
}
