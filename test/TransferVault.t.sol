// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TransferVault.sol";

contract ReentrancyAttacker {
    TransferVault public immutable vault;
    uint256 public immutable withdrawAmount;
    bool public reentered;

    constructor(TransferVault vault_, uint256 withdrawAmount_) {
        vault = vault_;
        withdrawAmount = withdrawAmount_;
    }

    function attack(uint256 depositAmount) external {
        vault.deposit{value: depositAmount}();
        vault.withdraw(withdrawAmount);
    }

    receive() external payable {
        if (!reentered && address(vault).balance >= withdrawAmount) {
            reentered = true;
            vault.withdraw(withdrawAmount);
        }
    }
}

contract TransferVaultTest is Test {
    TransferVault public transferVault;
    PaymentSplitter public paymentSplitter;
    ReentrancyAttacker public reentrancyAttacker;
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event ETHTransferred(address indexed caller, address indexed to, uint256 amount);
    event PayeeAdded(address indexed payee, uint256 shares);
    event PaymentSplit(address indexed sender, uint256 amount);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        transferVault = new TransferVault();
        paymentSplitter = new PaymentSplitter();
        reentrancyAttacker = new ReentrancyAttacker(transferVault, 1 ether);

        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(address(reentrancyAttacker), 10 ether);
    }

    function testInitialState() public {
        assertEq(transferVault.balances(user1), 0);
        assertEq(address(transferVault).balance, 0);
        assertEq(paymentSplitter.totalShares(), 0);
        assertEq(owner, address(this));
    }

    function testDeposit() public {
        uint256 amount = 2 ether;

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit Deposit(user1, amount);
        transferVault.deposit{value: amount}();

        assertEq(transferVault.balances(user1), amount);
        assertEq(address(transferVault).balance, amount);
    }

    function testWithdraw() public {
        uint256 amount = 3 ether;

        vm.startPrank(user1);
        transferVault.deposit{value: amount}();

        uint256 balanceBefore = user1.balance;
        vm.expectEmit(true, false, false, true);
        emit Withdrawal(user1, amount);
        transferVault.withdraw(amount);
        vm.stopPrank();

        assertEq(user1.balance, balanceBefore + amount);
        assertEq(transferVault.balances(user1), 0);
    }

    function testTransferETH() public {
        uint256 depositAmount = 5 ether;
        uint256 transferAmount = 1 ether;

        vm.prank(user1);
        transferVault.deposit{value: depositAmount}();

        uint256 callerBalanceBefore = user3.balance;

        vm.prank(user3);
        vm.expectEmit(true, true, false, true);
        emit ETHTransferred(user3, user2, transferAmount);
        transferVault.transferETH(user2, transferAmount);

        assertEq(user3.balance, callerBalanceBefore + transferAmount);
        assertEq(user2.balance, 100 ether);
    }

    function testPaymentSplitterSplitPayment() public {
        vm.expectEmit(true, false, false, true);
        emit PayeeAdded(user1, 1);
        paymentSplitter.addPayee(user1, 1);

        vm.expectEmit(true, false, false, true);
        emit PayeeAdded(user2, 3);
        paymentSplitter.addPayee(user2, 3);

        uint256 user1Before = user1.balance;
        uint256 user2Before = user2.balance;

        vm.expectEmit(true, false, false, true);
        emit PaymentSplit(address(this), 4 ether);
        paymentSplitter.splitPayment{value: 4 ether}();

        assertEq(user1.balance, user1Before + 1 ether);
        assertEq(user2.balance, user2Before + 3 ether);
    }

    function test_RevertWhen_DepositZero() public {
        vm.prank(user1);
        vm.expectRevert("Invalid deposit");
        transferVault.deposit{value: 0}();
    }

    function test_RevertWhen_WithdrawWithoutBalance() public {
        vm.prank(user1);
        vm.expectRevert("Insufficient balance");
        transferVault.withdraw(1 ether);
    }

    function test_RevertWhen_SplitPaymentWithoutPayees() public {
        vm.expectRevert(PaymentSplitter.NoPayees.selector);
        paymentSplitter.splitPayment{value: 1 ether}();
    }

    function testWithdrawReentrancy() public {
        vm.prank(user1);
        transferVault.deposit{value: 5 ether}();

        uint256 attackerBalanceBefore = address(reentrancyAttacker).balance;
        uint256 vaultBalanceBefore = address(transferVault).balance;

        reentrancyAttacker.attack(2 ether);

        uint256 attackerBalanceAfter = address(reentrancyAttacker).balance;
        uint256 vaultBalanceAfter = address(transferVault).balance;

        assertEq(attackerBalanceAfter, attackerBalanceBefore);
        assertEq(vaultBalanceAfter, vaultBalanceBefore);
        assertTrue(reentrancyAttacker.reentered());
    }

    function testTransferETHSendsToCallerNotRecipient() public {
        uint256 depositAmount = 3 ether;
        uint256 transferAmount = 2 ether;

        vm.prank(user1);
        transferVault.deposit{value: depositAmount}();

        uint256 callerBefore = user3.balance;
        uint256 recipientBefore = user2.balance;

        vm.prank(user3);
        transferVault.transferETH(user2, transferAmount);

        assertEq(user3.balance, callerBefore + transferAmount);
        assertEq(user2.balance, recipientBefore);
    }

    function testAddPayeeAccessControlIssue() public {
        vm.prank(user3);
        paymentSplitter.addPayee(user3, 50);

        assertEq(paymentSplitter.shares(user3), 50);
        assertEq(paymentSplitter.totalShares(), 50);
        assertEq(paymentSplitter.payees(0), user3);
    }

    receive() external payable {}
}
