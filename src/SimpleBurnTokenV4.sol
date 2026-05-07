// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SimpleBurnTokenV4
 * @dev Minimal ERC20 token with burn and burnFrom support.
 */
contract SimpleBurnTokenV4 {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Sets token metadata and mints `initialSupply` to the deployer.
     * @param name_ Token name.
     * @param symbol_ Token symbol.
     * @param decimals_ Token decimals.
     * @param initialSupply Initial token supply minted to deployer.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 initialSupply
    ) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
        _mint(msg.sender, initialSupply);
    }

    /**
     * @dev Transfers `amount` tokens from caller to `to`.
     * @param to Recipient address.
     * @param amount Amount to transfer.
     * @return True when transfer succeeds.
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /**
     * @dev Approves `spender` to spend `amount` from caller's balance.
     * @param spender Spender address.
     * @param amount Allowance amount.
     * @return True when approval succeeds.
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev Transfers `amount` from `from` to `to` using caller allowance.
     * @param from Owner address.
     * @param to Recipient address.
     * @param amount Amount to transfer.
     * @return True when transfer succeeds.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Burns caller tokens and reduces total supply.
     * @param amount Amount to burn.
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Burns tokens from `account` using caller allowance.
     * @param account Token owner address.
     * @param amount Amount to burn.
     */
    function burnFrom(address account, uint256 amount) external {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = balanceOf[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");

        unchecked {
            balanceOf[from] = fromBalance - amount;
        }
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                allowance[owner][spender] = currentAllowance - amount;
            }
            emit Approval(owner, spender, allowance[owner][spender]);
        }
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        totalSupply += amount;
        balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = balanceOf[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");

        unchecked {
            balanceOf[account] = accountBalance - amount;
            totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);
    }
}
