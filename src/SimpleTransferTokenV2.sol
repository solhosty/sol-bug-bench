// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SimpleTransferTokenV2
 * @dev Minimal fixed-supply ERC20-like token implementation.
 */
contract SimpleTransferTokenV2 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @param initialSupply The fixed token supply assigned to the deployer.
     */
    constructor(uint256 initialSupply) {
        name = "Simple Transfer Token V2";
        symbol = "STTV2";

        totalSupply = initialSupply;
        balanceOf[msg.sender] = initialSupply;

        emit Transfer(address(0), msg.sender, initialSupply);
    }

    /**
     * @param to Recipient address.
     * @param amount Amount to transfer.
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        require(to != address(0), "Invalid recipient");
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @param spender Address allowed to spend tokens.
     * @param amount Allowance amount.
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        require(spender != address(0), "Invalid spender");

        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @param from Address to transfer from.
     * @param to Recipient address.
     * @param amount Amount to transfer.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(from != address(0), "Invalid sender");
        require(to != address(0), "Invalid recipient");
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }
}
