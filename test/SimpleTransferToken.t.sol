// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleTransferToken.sol";

contract SimpleTransferTokenTest is Test {
    SimpleTransferToken internal token;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal charlie = address(0xC0FFEE);

    function setUp() public {
        token = new SimpleTransferToken();
    }

    function testInitialSupplyAssignedToDeployer() public {
        assertEq(token.totalSupply(), token.INITIAL_SUPPLY());
        assertEq(token.balanceOf(address(this)), token.INITIAL_SUPPLY());
    }

    function testTransferUpdatesBalances() public {
        uint256 amount = 250 * 10 ** 18;

        assertTrue(token.transfer(alice, amount));
        assertEq(token.balanceOf(address(this)), token.INITIAL_SUPPLY() - amount);
        assertEq(token.balanceOf(alice), amount);
    }

    function testApproveAndTransferFromUpdatesAllowanceAndBalances() public {
        uint256 transferAmount = 100 * 10 ** 18;
        uint256 approvalAmount = 300 * 10 ** 18;

        token.transfer(alice, approvalAmount);

        vm.prank(alice);
        assertTrue(token.approve(bob, approvalAmount));
        assertEq(token.allowance(alice, bob), approvalAmount);

        vm.prank(bob);
        assertTrue(token.transferFrom(alice, charlie, transferAmount));

        assertEq(token.balanceOf(alice), approvalAmount - transferAmount);
        assertEq(token.balanceOf(charlie), transferAmount);
        assertEq(token.allowance(alice, bob), approvalAmount - transferAmount);
    }

    function testTransferRevertsOnInsufficientBalance() public {
        uint256 amount = 1;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                SimpleTransferToken.InsufficientBalance.selector,
                alice,
                0,
                amount
            )
        );
        token.transfer(bob, amount);
    }

    function testApproveRevertsOnZeroSpender() public {
        vm.expectRevert(
            abi.encodeWithSelector(SimpleTransferToken.InvalidSpender.selector, address(0))
        );
        token.approve(address(0), 1);
    }

    function testTransferRevertsOnZeroReceiver() public {
        vm.expectRevert(
            abi.encodeWithSelector(SimpleTransferToken.InvalidReceiver.selector, address(0))
        );
        token.transfer(address(0), 1);
    }

    function testTransferFromRevertsOnInsufficientAllowance() public {
        uint256 ownerTokens = 20 * 10 ** 18;
        uint256 approved = 5 * 10 ** 18;
        uint256 attempted = 10 * 10 ** 18;

        token.transfer(alice, ownerTokens);

        vm.prank(alice);
        token.approve(bob, approved);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                SimpleTransferToken.InsufficientAllowance.selector,
                bob,
                approved,
                attempted
            )
        );
        token.transferFrom(alice, charlie, attempted);
    }

    function testTransferFromRevertsOnInsufficientBalance() public {
        uint256 approved = 100 * 10 ** 18;
        uint256 attempted = 75 * 10 ** 18;

        token.transfer(alice, 50 * 10 ** 18);

        vm.prank(alice);
        token.approve(bob, approved);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                SimpleTransferToken.InsufficientBalance.selector,
                alice,
                50 * 10 ** 18,
                attempted
            )
        );
        token.transferFrom(alice, charlie, attempted);
    }
}
