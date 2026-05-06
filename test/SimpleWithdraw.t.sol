// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleWithdraw.sol";

contract SimpleWithdrawTest is Test {
    SimpleWithdraw public vault;
    address public alice;
    address public bob;

    function setUp() public {
        vault = new SimpleWithdraw();
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function test_Deposit() public {
        vm.prank(alice);
        vault.deposit{value: 1 ether}();

        assertEq(vault.getBalance(alice), 1 ether);
        assertEq(address(vault).balance, 1 ether);
    }

    function test_DepositViaReceive() public {
        vm.prank(alice);
        (bool success, ) = address(vault).call{value: 1 ether}("");
        assertTrue(success);

        assertEq(vault.getBalance(alice), 1 ether);
        assertEq(address(vault).balance, 1 ether);
    }

    function test_Withdraw() public {
        vm.startPrank(alice);
        vault.deposit{value: 2 ether}();

        uint256 beforeBalance = alice.balance;
        vault.withdraw(1 ether);
        uint256 afterBalance = alice.balance;
        vm.stopPrank();

        assertEq(vault.getBalance(alice), 1 ether);
        assertEq(afterBalance, beforeBalance + 1 ether);
    }

    function test_RevertWhen_WithdrawExceedsBalance() public {
        vm.startPrank(alice);
        vault.deposit{value: 1 ether}();

        vm.expectRevert();
        vault.withdraw(2 ether);
        vm.stopPrank();
    }

    function test_MultipleUsers() public {
        vm.prank(alice);
        vault.deposit{value: 3 ether}();

        vm.prank(bob);
        vault.deposit{value: 1 ether}();

        vm.prank(alice);
        vault.withdraw(3 ether);

        vm.prank(bob);
        vault.withdraw(1 ether);

        assertEq(vault.getBalance(alice), 0);
        assertEq(vault.getBalance(bob), 0);
        assertEq(address(vault).balance, 0);
    }
}
