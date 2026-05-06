// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleTransferToken {
    string public constant name = "Simple Transfer Token";
    string public constant symbol = "STT";
    uint8 public constant decimals = 18;

    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    error InsufficientBalance(address account, uint256 balance, uint256 needed);
    error InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error InvalidSender(address sender);
    error InvalidReceiver(address receiver);
    error InvalidSpender(address spender);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        totalSupply = INITIAL_SUPPLY;
        balanceOf[msg.sender] = INITIAL_SUPPLY;

        emit Transfer(address(0), msg.sender, INITIAL_SUPPLY);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        if (spender == address(0)) revert InvalidSpender(address(0));

        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance < value) {
            revert InsufficientAllowance(msg.sender, currentAllowance, value);
        }

        allowance[from][msg.sender] = currentAllowance - value;
        emit Approval(from, msg.sender, allowance[from][msg.sender]);

        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) revert InvalidSender(address(0));
        if (to == address(0)) revert InvalidReceiver(address(0));

        uint256 fromBalance = balanceOf[from];
        if (fromBalance < value) {
            revert InsufficientBalance(from, fromBalance, value);
        }

        unchecked {
            balanceOf[from] = fromBalance - value;
        }
        balanceOf[to] += value;

        emit Transfer(from, to, value);
    }
}
