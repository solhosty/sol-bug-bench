// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SimpleBurnTokenV10
/// @notice Dependency-free ERC20 token with burn and burnFrom support.
contract SimpleBurnTokenV10 {
    string private _name;
    string private _symbol;
    uint8 private constant _DECIMALS = 18;
    uint256 private _totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice Deploys the token and mints initial supply to deployer.
    /// @param name_ Token name.
    /// @param symbol_ Token symbol.
    /// @param initialSupply Initial token supply minted to msg.sender.
    constructor(string memory name_, string memory symbol_, uint256 initialSupply) {
        _name = name_;
        _symbol = symbol_;
        _mint(msg.sender, initialSupply);
    }

    /// @notice Returns the token name.
    /// @return Token name.
    function name() external view returns (string memory) {
        return _name;
    }

    /// @notice Returns the token symbol.
    /// @return Token symbol.
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    /// @notice Returns token decimals.
    /// @return Number of decimal places.
    function decimals() external pure returns (uint8) {
        return _DECIMALS;
    }

    /// @notice Returns the total token supply.
    /// @return Total supply.
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /// @notice Returns the token balance of an account.
    /// @param account Address to query.
    /// @return Account balance.
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    /// @notice Transfers tokens to another account.
    /// @param to Recipient account.
    /// @param amount Amount to transfer.
    /// @return True when successful.
    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    /// @notice Returns allowance from owner to spender.
    /// @param owner Token owner.
    /// @param spender Allowance spender.
    /// @return Remaining allowance.
    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    /// @notice Approves a spender to spend caller tokens.
    /// @param spender Account allowed to spend.
    /// @param amount Allowance amount.
    /// @return True when successful.
    function approve(address spender, uint256 amount) external returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(
            amount == 0 || currentAllowance == 0,
            "ERC20: approve from non-zero to non-zero allowance"
        );

        _approve(msg.sender, spender, amount);
        return true;
    }

    /// @notice Transfers tokens using allowance.
    /// @param from Source account.
    /// @param to Recipient account.
    /// @param amount Amount to transfer.
    /// @return True when successful.
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /// @notice Burns caller tokens and decreases total supply.
    /// @param amount Amount to burn.
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /// @notice Burns tokens from an account using allowance.
    /// @param account Account to burn from.
    /// @param amount Amount to burn.
    function burnFrom(address account, uint256 amount) external {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");

        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = _allowances[owner][spender];
        require(currentAllowance >= amount, "ERC20: insufficient allowance");

        unchecked {
            _allowances[owner][spender] = currentAllowance - amount;
        }

        emit Approval(owner, spender, _allowances[owner][spender]);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;

        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");

        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }
}
