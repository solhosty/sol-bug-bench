// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title SimpleMintTokenV2
/// @dev Minimal ERC20-like token with owner-restricted minting.
contract SimpleMintTokenV2 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    address public owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @dev Sets token metadata and owner.
    constructor() {
        name = "Simple Mint Token V2";
        symbol = "SMTV2";
        owner = msg.sender;
    }

    /// @dev Transfers tokens from msg.sender to `to`.
    /// @param to Recipient address.
    /// @param amount Amount of tokens to transfer.
    /// @return True when transfer succeeds.
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /// @dev Sets allowance for `spender` over msg.sender tokens.
    /// @param spender Address that can spend tokens.
    /// @param amount Maximum amount spender can transfer.
    /// @return True when approval succeeds.
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @dev Transfers tokens from `from` to `to` using msg.sender allowance.
    /// @param from Address tokens are moved from.
    /// @param to Recipient address.
    /// @param amount Amount of tokens to transfer.
    /// @return True when transfer succeeds.
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "Insufficient allowance");

        allowance[from][msg.sender] = allowed - amount;
        emit Approval(from, msg.sender, allowance[from][msg.sender]);

        _transfer(from, to, amount);
        return true;
    }

    /// @dev Mints tokens to `to`. Only callable by owner.
    /// @param to Recipient address.
    /// @param amount Amount of tokens to mint.
    function mint(address to, uint256 amount) external {
        require(msg.sender == owner, "Not owner");
        require(to != address(0), "Invalid recipient");

        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "Invalid recipient");
        require(balanceOf[from] >= amount, "Insufficient balance");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }
}
