// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SimpleBurnTokenV7
 * @dev Minimal ERC20 token implementation with burn and burnFrom support.
 */
contract SimpleBurnTokenV7 {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @param name_ Token name.
     * @param symbol_ Token symbol.
     * @param decimals_ Token decimals.
     * @param initialSupply_ Initial token supply minted to deployer.
     */
    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 initialSupply_) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
        _mint(msg.sender, initialSupply_);
    }

    /**
     * @notice Transfers tokens from caller to recipient.
     * @param to Recipient address.
     * @param amount Amount to transfer.
     * @return True when transfer succeeds.
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @notice Sets allowance for a spender.
     * @param spender Spender address.
     * @param amount Allowance amount.
     * @return True when approval succeeds.
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        require(
            amount == 0 || allowance[msg.sender][spender] == 0,
            "Reset allowance to zero first"
        );
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Transfers tokens from owner to recipient using caller allowance.
     * @param from Owner address.
     * @param to Recipient address.
     * @param amount Amount to transfer.
     * @return True when transfer succeeds.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        require(currentAllowance >= amount, "Insufficient allowance");

        _approve(from, msg.sender, currentAllowance - amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @notice Burns caller tokens.
     * @param amount Amount to burn.
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @notice Burns tokens from an account using caller allowance.
     * @param account Account whose tokens are burned.
     * @param amount Amount to burn.
     */
    function burnFrom(address account, uint256 amount) external {
        uint256 currentAllowance = allowance[account][msg.sender];
        require(currentAllowance >= amount, "Insufficient allowance");

        _approve(account, msg.sender, currentAllowance - amount);
        _burn(account, amount);
    }

    /**
     * @dev Transfers tokens between two addresses.
     */
    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "Invalid recipient");
        require(balanceOf[from] >= amount, "Insufficient balance");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    /**
     * @dev Sets token allowance from owner to spender.
     */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(spender != address(0), "Invalid spender");

        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Mints tokens to an account.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "Invalid account");

        totalSupply += amount;
        balanceOf[account] += amount;

        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Burns tokens from an account.
     */
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "Invalid account");
        require(balanceOf[account] >= amount, "Insufficient balance");

        balanceOf[account] -= amount;
        totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }
}
