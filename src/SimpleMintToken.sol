// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SimpleMintToken {
    error NotOwner();
    error InvalidReceiver();
    error InvalidSpender();
    error InsufficientBalance(address account, uint256 balance, uint256 needed);
    error InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    address public immutable owner;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory tokenName, string memory tokenSymbol) {
        name = tokenName;
        symbol = tokenSymbol;
        owner = msg.sender;
    }

    function mint(address to, uint256 amount) external {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _mint(to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) {
            revert InvalidSpender();
        }

        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];

        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) {
                revert InsufficientAllowance(msg.sender, currentAllowance, amount);
            }

            unchecked {
                allowance[from][msg.sender] = currentAllowance - amount;
            }
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }

        _transfer(from, to, amount);
        return true;
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) {
            revert InvalidReceiver();
        }

        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) {
            revert InvalidReceiver();
        }

        uint256 fromBalance = balanceOf[from];
        if (fromBalance < amount) {
            revert InsufficientBalance(from, fromBalance, amount);
        }

        unchecked {
            balanceOf[from] = fromBalance - amount;
        }
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}
