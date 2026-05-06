// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Withdraw.sol";

contract WithdrawTest is Test {
    Withdraw public withdrawContract;
    address public alice;
    address public bob;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    function setUp() public {
        withdrawContract = new Withdraw();
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testDepositUpdatesBalanceAndEmits() public {
        uint256 amount = 1 ether;

        vm.expectEmit(true, true, true, true);
        emit Deposited(alice, amount);

        vm.prank(alice);
        withdrawContract.deposit{value: amount}();

        assertEq(withdrawContract.balances(alice), amount);
        assertEq(withdrawContract.getBalance(alice), amount);
    }

    function testWithdrawSendsEthAndEmits() public {
        uint256 amount = 1 ether;
        uint256 aliceBalanceBefore = alice.balance;

        vm.prank(alice);
        withdrawContract.deposit{value: amount}();

        vm.expectEmit(true, true, true, true);
        emit Withdrawn(alice, amount);

        vm.prank(alice);
        withdrawContract.withdraw(amount);

        assertEq(alice.balance, aliceBalanceBefore);
    }

    function testFullWithdrawalZeroesBalance() public {
        uint256 amount = 2 ether;

        vm.prank(alice);
        withdrawContract.deposit{value: amount}();

        vm.prank(alice);
        withdrawContract.withdraw(amount);

        assertEq(withdrawContract.balances(alice), 0);
        assertEq(withdrawContract.getBalance(alice), 0);
    }

    function testDepositRevertsOnZeroAmount() public {
        vm.expectRevert("Amount must be greater than 0");

        vm.prank(alice);
        withdrawContract.deposit{value: 0}();
    }

    function testWithdrawRevertsOnZeroAmount() public {
        vm.prank(alice);
        withdrawContract.deposit{value: 1 ether}();

        vm.expectRevert("Amount must be greater than 0");

        vm.prank(alice);
        withdrawContract.withdraw(0);
    }

    function testWithdrawRevertsWhenExceedingBalance() public {
        vm.prank(alice);
        withdrawContract.deposit{value: 1 ether}();

        vm.expectRevert("Insufficient balance");

        vm.prank(alice);
        withdrawContract.withdraw(2 ether);
    }

    function testWithdrawRevertsWithNoPriorDeposit() public {
        vm.expectRevert("Insufficient balance");

        vm.prank(bob);
        withdrawContract.withdraw(1);
    }
}
