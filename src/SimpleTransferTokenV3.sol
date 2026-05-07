// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title SimpleTransferTokenV3
/// @dev Minimal fixed-supply ERC20-like token implementation.
contract SimpleTransferTokenV3 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @param initialSupply The total token supply minted to the deployer.
    constructor(uint256 initialSupply) {
        name = "Simple Transfer Token V3";
        symbol = "STTV3";
        decimals = 18;

        totalSupply = initialSupply;
        balanceOf[msg.sender] = initialSupply;

        emit Transfer(address(0), msg.sender, initialSupply);
    }

    /// @param to Recipient address.
    /// @param amount Amount to transfer.
    /// @return success True when transfer succeeds.
    function transfer(address to, uint256 amount) external returns (bool success) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /// @param spender Address allowed to spend tokens.
    /// @param amount Allowance amount.
    /// @return success True when approval succeeds.
    function approve(address spender, uint256 amount) external returns (bool success) {
        require(
            amount == 0 || allowance[msg.sender][spender] == 0,
            "Must reset allowance to zero first"
        );
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @param from Source account.
    /// @param to Recipient account.
    /// @param amount Amount to transfer.
    /// @return success True when transfer succeeds.
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool success) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }
}
