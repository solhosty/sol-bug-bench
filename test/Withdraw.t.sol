// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Withdraw.sol";

contract WithdrawTest is Test {
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    Withdraw internal withdrawContract;

    function setUp() public {
        withdrawContract = new Withdraw();
    }

    function test_deposit_increases_balance_and_emits() public {
        address user = address(0xA11CE);
        uint256 amount = 1 ether;

        vm.deal(user, amount);

        vm.expectEmit(true, false, false, true, address(withdrawContract));
        emit Deposited(user, amount);

        vm.prank(user);
        withdrawContract.deposit{value: amount}();

        assertEq(withdrawContract.balances(user), amount);
    }

    function test_withdraw_decreases_balance_transfers_eth_and_emits() public {
        address user = address(0xB0B);
        uint256 depositAmount = 2 ether;
        uint256 withdrawAmount = 1 ether;

        vm.deal(user, depositAmount);

        vm.prank(user);
        withdrawContract.deposit{value: depositAmount}();

        uint256 userBalanceBefore = user.balance;

        vm.expectEmit(true, false, false, true, address(withdrawContract));
        emit Withdrawn(user, withdrawAmount);

        vm.prank(user);
        withdrawContract.withdraw(withdrawAmount);

        assertEq(withdrawContract.balances(user), depositAmount - withdrawAmount);
        assertEq(user.balance, userBalanceBefore + withdrawAmount);
    }

    function test_withdraw_reverts_insufficient_balance() public {
        address user = address(0xCAFE);

        vm.deal(user, 1 ether);

        vm.prank(user);
        withdrawContract.deposit{value: 1 ether}();

        vm.expectRevert(Withdraw.InsufficientBalance.selector);
        vm.prank(user);
        withdrawContract.withdraw(2 ether);
    }

    function test_withdraw_reverts_zero_balance() public {
        address user = address(0xD00D);

        vm.expectRevert(Withdraw.InsufficientBalance.selector);
        vm.prank(user);
        withdrawContract.withdraw(1 ether);
    }

    function test_balances_returns_correct_value() public {
        address user = address(0xABCD);
        uint256 amount = 0.75 ether;

        vm.deal(user, amount);

        vm.prank(user);
        withdrawContract.deposit{value: amount}();

        assertEq(withdrawContract.balances(user), amount);
    }

    function test_multiple_users_independent_balances() public {
        address userA = address(0xA1);
        address userB = address(0xB2);
        uint256 amountA = 1 ether;
        uint256 amountB = 2 ether;

        vm.deal(userA, amountA);
        vm.deal(userB, amountB);

        vm.prank(userA);
        withdrawContract.deposit{value: amountA}();

        vm.prank(userB);
        withdrawContract.deposit{value: amountB}();

        assertEq(withdrawContract.balances(userA), amountA);
        assertEq(withdrawContract.balances(userB), amountB);
    }

    function test_partial_withdraw() public {
        address user = address(0xEE);
        uint256 depositAmount = 3 ether;

        vm.deal(user, depositAmount);

        vm.prank(user);
        withdrawContract.deposit{value: depositAmount}();

        vm.prank(user);
        withdrawContract.withdraw(1 ether);

        assertEq(withdrawContract.balances(user), 2 ether);
    }

    function test_full_withdraw_zeroes_balance() public {
        address user = address(0xFA);
        uint256 amount = 1.5 ether;

        vm.deal(user, amount);

        vm.prank(user);
        withdrawContract.deposit{value: amount}();

        vm.prank(user);
        withdrawContract.withdraw(amount);

        assertEq(withdrawContract.balances(user), 0);
    }
}
