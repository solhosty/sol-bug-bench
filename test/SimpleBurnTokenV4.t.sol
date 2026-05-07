// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SimpleBurnTokenV4.sol";

contract SimpleBurnTokenV4Test is Test {
    event Transfer(address indexed from, address indexed to, uint256 value);

    SimpleBurnTokenV4 internal token;

    address internal owner;
    address internal user1;
    address internal user2;

    uint256 internal constant INITIAL_SUPPLY = 1_000_000 ether;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        token = new SimpleBurnTokenV4("Simple Burn Token V4", "SBTV4", 18, INITIAL_SUPPLY);
    }

    function testInitialSupply() public {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.name(), "Simple Burn Token V4");
        assertEq(token.symbol(), "SBTV4");
        assertEq(token.decimals(), 18);
    }

    function testTransfer() public {
        uint256 amount = 250 ether;

        bool success = token.transfer(user1, amount);

        assertTrue(success);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount);
        assertEq(token.balanceOf(user1), amount);
    }

    function testApproveAndTransferFrom() public {
        uint256 approved = 500 ether;
        uint256 spent = 200 ether;

        token.approve(user1, approved);

        vm.prank(user1);
        bool success = token.transferFrom(owner, user2, spent);

        assertTrue(success);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - spent);
        assertEq(token.balanceOf(user2), spent);
        assertEq(token.allowance(owner, user1), approved - spent);
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
}
