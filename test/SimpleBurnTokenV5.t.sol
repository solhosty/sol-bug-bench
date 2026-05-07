// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleBurnTokenV5.sol";

contract SimpleBurnTokenV5Test is Test {
    event Transfer(address indexed from, address indexed to, uint256 value);

    SimpleBurnTokenV5 internal token;

    address internal owner;
    address internal user1;
    address internal user2;

    uint256 internal constant INITIAL_SUPPLY = 1_000_000 ether;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        token = new SimpleBurnTokenV5("Simple Burn Token V5", "SBTV5", 18, INITIAL_SUPPLY);
    }

    function testInitialSupply() public {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.name(), "Simple Burn Token V5");
        assertEq(token.symbol(), "SBTV5");
        assertEq(token.decimals(), 18);
    }

    function testTransfer() public {
        uint256 amount = 250 ether;

        bool success = token.transfer(user1, amount);

        assertTrue(success);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount);
        assertEq(token.balanceOf(user1), amount);
    }

    function testBurnReducesBalanceAndSupplyAndEmitsTransferToZero() public {
        uint256 amount = 100 ether;
        uint256 supplyBefore = token.totalSupply();
        uint256 balanceBefore = token.balanceOf(owner);

        vm.expectEmit(true, true, true, true);
        emit Transfer(owner, address(0), amount);

        token.burn(amount);

        assertEq(token.balanceOf(owner), balanceBefore - amount);
        assertEq(token.totalSupply(), supplyBefore - amount);
    }

    function testBurnFromRespectsAllowance() public {
        uint256 burnAmount = 120 ether;

        bool transferSuccess = token.transfer(user1, burnAmount);
        assertTrue(transferSuccess);

        vm.prank(user1);
        token.approve(owner, burnAmount);

        token.burnFrom(user1, burnAmount);

        assertEq(token.balanceOf(user1), 0);
        assertEq(token.allowance(user1, owner), 0);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - burnAmount);
    }

    function testBurnFromWithFiniteAllowanceDecrementsRemainingAllowance() public {
        uint256 userBalance = 200 ether;
        uint256 approved = 150 ether;
        uint256 burnAmount = 60 ether;

        bool transferSuccess = token.transfer(user1, userBalance);
        assertTrue(transferSuccess);

        vm.prank(user1);
        token.approve(owner, approved);

        token.burnFrom(user1, burnAmount);

        assertEq(token.balanceOf(user1), userBalance - burnAmount);
        assertEq(token.allowance(user1, owner), approved - burnAmount);
    }

    function test_RevertWhen_BurnInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        token.burn(1);
    }

    function test_RevertWhen_BurnFromInsufficientAllowance() public {
        uint256 amount = 50 ether;

        bool transferSuccess = token.transfer(user1, amount);
        assertTrue(transferSuccess);

        vm.prank(user2);
        vm.expectRevert("ERC20: insufficient allowance");
        token.burnFrom(user1, 1);
    }

    function test_RevertWhen_TransferExceedsBalance() public {
        vm.prank(user1);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        bool success = token.transfer(user2, 1);
        success;
    }
}
