// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleTransferTokenV3.sol";

contract SimpleTransferTokenV3Test is Test {
    SimpleTransferTokenV3 public token;

    address public owner;
    address public user1;
    address public user2;

    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        token = new SimpleTransferTokenV3(INITIAL_SUPPLY);
    }

    function testDeployerReceivesFullInitialSupply() public {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.balanceOf(user1), 0);
    }

    function testTransfer() public {
        uint256 amount = 100 ether;

        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, user1, amount);

        bool success = token.transfer(user1, amount);

        assertTrue(success);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount);
        assertEq(token.balanceOf(user1), amount);
    }

    function test_RevertWhen_TransferInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert("Insufficient balance");
        bool success = token.transfer(user2, 1);
        success;
    }

    function testApproveAndTransferFrom() public {
        uint256 amount = 75 ether;

        token.approve(user1, amount);

        vm.prank(user1);
        bool success = token.transferFrom(owner, user2, amount);

        assertTrue(success);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount);
        assertEq(token.balanceOf(user2), amount);
        assertEq(token.allowance(owner, user1), 0);
    }

    function test_RevertWhen_ApproveNonZeroToNonZeroAllowance() public {
        token.approve(user1, 10 ether);

        vm.expectRevert("Must reset allowance to zero first");
        token.approve(user1, 20 ether);
    }

    function test_RevertWhen_TransferFromInsufficientAllowance() public {
        token.approve(user1, 10 ether);

        vm.prank(user1);
        vm.expectRevert("Insufficient allowance");
        bool success = token.transferFrom(owner, user2, 11 ether);
        success;
    }
}
