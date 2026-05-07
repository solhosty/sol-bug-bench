// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleTransferTokenV2.sol";

contract SimpleTransferTokenV2Test is Test {
    SimpleTransferTokenV2 public token;

    address public deployer;
    address public user1;
    address public user2;

    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        deployer = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        token = new SimpleTransferTokenV2(INITIAL_SUPPLY);
    }

    function testInitialSupplyAssignedToDeployer() public {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY);
        assertEq(token.balanceOf(user1), 0);
    }

    function testTransferSuccess() public {
        uint256 amount = 100 ether;

        vm.expectEmit(true, true, true, true);
        emit Transfer(deployer, user1, amount);

        bool ok = token.transfer(user1, amount);

        assertTrue(ok);
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - amount);
        assertEq(token.balanceOf(user1), amount);
    }

    function test_RevertWhen_TransferInsufficientBalance() public {
        uint256 amount = 1;

        vm.prank(user1);
        vm.expectRevert("Insufficient balance");
        token.transfer(user2, amount);
    }

    function testApproveAndTransferFromSuccess() public {
        uint256 approvalAmount = 250 ether;
        uint256 transferAmount = 200 ether;

        bool approved = token.approve(user1, approvalAmount);
        assertTrue(approved);
        assertEq(token.allowance(deployer, user1), approvalAmount);

        vm.prank(user1);
        bool ok = token.transferFrom(deployer, user2, transferAmount);

        assertTrue(ok);
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - transferAmount);
        assertEq(token.balanceOf(user2), transferAmount);
        assertEq(token.allowance(deployer, user1), approvalAmount - transferAmount);
    }

    function test_RevertWhen_TransferFromInsufficientAllowance() public {
        token.approve(user1, 10 ether);

        vm.prank(user1);
        vm.expectRevert("Insufficient allowance");
        token.transferFrom(deployer, user2, 20 ether);
    }
}
