// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TransferToken.sol";

contract TransferTokenTest is Test {
    TransferToken internal token;

    address internal deployer;
    address internal user1;
    address internal user2;

    uint256 internal constant INITIAL_SUPPLY = 1_000_000 ether;

    function setUp() public {
        deployer = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        token = new TransferToken("Transfer Token", "TRT", INITIAL_SUPPLY);
    }

    function testInitialSupplyMintedToDeployer() public {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY);
        assertEq(token.balanceOf(user1), 0);
    }

    function testTransferSuccess() public {
        uint256 amount = 100 ether;

        bool success = token.transfer(user1, amount);

        assertTrue(success);
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - amount);
        assertEq(token.balanceOf(user1), amount);
    }

    function testTransferRevertsOnInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert(bytes("ERC20: insufficient balance"));
        token.transfer(user2, 1 ether);
    }

    function testApproveAndTransferFromSuccess() public {
        uint256 approved = 250 ether;
        uint256 spent = 120 ether;

        bool approveSuccess = token.approve(user1, approved);
        assertTrue(approveSuccess);
        assertEq(token.allowance(deployer, user1), approved);

        vm.prank(user1);
        bool transferFromSuccess = token.transferFrom(deployer, user2, spent);

        assertTrue(transferFromSuccess);
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - spent);
        assertEq(token.balanceOf(user2), spent);
        assertEq(token.allowance(deployer, user1), approved - spent);
    }

    function testTransferFromRevertsOnInsufficientAllowance() public {
        uint256 approved = 50 ether;

        token.approve(user1, approved);

        vm.prank(user1);
        vm.expectRevert(bytes("ERC20: insufficient allowance"));
        token.transferFrom(deployer, user2, 100 ether);
    }
}
