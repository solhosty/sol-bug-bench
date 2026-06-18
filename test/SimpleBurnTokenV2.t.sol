// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleBurnTokenV2.sol";

contract SimpleBurnTokenV2Test is Test {
    SimpleBurnTokenV2 public token;
    address public owner;
    address public user1;
    address public user2;

    uint256 internal constant INITIAL_SUPPLY = 1_000_000 ether;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        token = new SimpleBurnTokenV2("Simple Burn Token V2", "SBTV2", INITIAL_SUPPLY);
    }

    function testInitialSupplyMintedToDeployer() public {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
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
        uint256 approvalAmount = 500 ether;
        uint256 transferAmount = 300 ether;

        token.approve(user1, approvalAmount);

        vm.prank(user1);
        bool success = token.transferFrom(owner, user2, transferAmount);

        assertTrue(success);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
        assertEq(token.balanceOf(user2), transferAmount);
        assertEq(token.allowance(owner, user1), approvalAmount - transferAmount);
    }

    function testBurnReducesBalanceAndSupplyAndEmitsTransferToZero() public {
        uint256 burnAmount = 1_000 ether;

        vm.expectEmit(true, true, true, true);
        emit Transfer(owner, address(0), burnAmount);

        token.burn(burnAmount);

        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - burnAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - burnAmount);
    }

    function testBurnFromUsesAllowance() public {
        uint256 burnAmount = 400 ether;
        uint256 approvedAmount = 900 ether;

        assertTrue(token.transfer(user1, 2_000 ether));

        vm.prank(user1);
        token.approve(user2, approvedAmount);

        vm.prank(user2);
        token.burnFrom(user1, burnAmount);

        assertEq(token.balanceOf(user1), 2_000 ether - burnAmount);
        assertEq(token.allowance(user1, user2), approvedAmount - burnAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - burnAmount);
    }

    function test_RevertWhen_BurnInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert("ERC20: insufficient balance");
        token.burn(1);
    }

    function test_RevertWhen_BurnFromInsufficientAllowance() public {
        assertTrue(token.transfer(user1, 100 ether));

        vm.prank(user2);
        vm.expectRevert("ERC20: insufficient allowance");
        token.burnFrom(user1, 1 ether);
    }

    function test_RevertWhen_BurnFromInsufficientBalance() public {
        uint256 approvedAmount = 10 ether;

        vm.prank(user1);
        token.approve(user2, approvedAmount);

        vm.prank(user2);
        vm.expectRevert("ERC20: insufficient balance");
        token.burnFrom(user1, approvedAmount);
    }
}
