// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

error ERC20InvalidSender(address sender);
error ERC20InvalidReceiver(address receiver);
error ERC20InvalidSpender(address spender);
error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

contract ERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;

    uint256 public totalSupply;

    mapping(address => uint256) internal balances;
    mapping(address => mapping(address => uint256)) internal allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return allowances[owner][spender];
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        if (msg.sender == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        virtual
        returns (bool)
    {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        uint256 currentAllowance = allowances[from][msg.sender];
        if (currentAllowance < amount) {
            revert ERC20InsufficientAllowance(msg.sender, currentAllowance, amount);
        }
        _transfer(from, to, amount);
        allowances[from][msg.sender] = currentAllowance - amount;
        emit Approval(from, msg.sender, allowances[from][msg.sender]);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        _beforeTokenTransfer(from, to, amount);
        uint256 senderBalance = balances[from];
        if (senderBalance < amount) {
            revert ERC20InsufficientBalance(from, senderBalance, amount);
        }
        balances[from] = senderBalance - amount;
        balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal virtual {
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _beforeTokenTransfer(address(0), to, amount);
        totalSupply += amount;
        balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _beforeTokenTransfer(from, address(0), amount);
        uint256 accountBalance = balances[from];
        if (accountBalance < amount) {
            revert ERC20InsufficientBalance(from, accountBalance, amount);
        }
        balances[from] = accountBalance - amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        virtual
    {}
}
