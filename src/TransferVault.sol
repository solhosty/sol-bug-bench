// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TransferVault {
    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event ETHTransferred(address indexed caller, address indexed to, uint256 amount);
    event EmergencyWithdrawal(address indexed caller, uint256 amount);

    function deposit() external payable {
        require(msg.value > 0, "Invalid deposit");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        balances[msg.sender] -= amount;
        emit Withdrawal(msg.sender, amount);
    }

    function transferETH(address to, uint256 amount) external {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        require(address(this).balance >= amount, "Insufficient vault balance");

        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit ETHTransferred(msg.sender, to, amount);
    }

    function emergencyWithdraw(uint256 amount) external {
        require(amount > 0, "Invalid amount");
        require(address(this).balance >= amount, "Insufficient vault balance");

        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit EmergencyWithdrawal(msg.sender, amount);
    }
}

contract PaymentSplitter {
    error InvalidShares();
    error InvalidPayee();
    error InvalidPayment();
    error NoPayees();
    error PaymentFailed();

    event PayeeAdded(address indexed payee, uint256 shares);
    event PaymentSplit(address indexed sender, uint256 amount);

    address[] public payees;
    mapping(address => uint256) public shares;
    uint256 public totalShares;

    function addPayee(address payee, uint256 payeeShares) external {
        if (payee == address(0)) {
            revert InvalidPayee();
        }
        if (payeeShares == 0) {
            revert InvalidShares();
        }

        if (shares[payee] == 0) {
            payees.push(payee);
        }

        shares[payee] += payeeShares;
        totalShares += payeeShares;

        emit PayeeAdded(payee, payeeShares);
    }

    function splitPayment() external payable {
        if (msg.value == 0) {
            revert InvalidPayment();
        }
        if (payees.length == 0 || totalShares == 0) {
            revert NoPayees();
        }

        uint256 length = payees.length;
        for (uint256 i = 0; i < length; i++) {
            address payee = payees[i];
            uint256 amount = (msg.value * shares[payee]) / totalShares;

            (bool success,) = payee.call{value: amount}("");
            if (!success) {
                revert PaymentFailed();
            }
        }

        emit PaymentSplit(msg.sender, msg.value);
    }
}
