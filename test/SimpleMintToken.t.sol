// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SimpleMintToken.sol";

contract SimpleMintTokenTest is Test {
    SimpleMintToken internal token;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal charlie = address(0xC0FFEE);

    function setUp() public {
        token = new SimpleMintToken("Simple Mint Token", "SMT");
        token.mint(alice, 100e18);
    }

    function testConstructorState() public {
        SimpleMintToken freshToken = new SimpleMintToken("Simple Mint Token", "SMT");

        assertEq(freshToken.name(), "Simple Mint Token");
        assertEq(freshToken.symbol(), "SMT");
        assertEq(freshToken.decimals(), 18);
        assertEq(freshToken.owner(), address(this));
        assertEq(freshToken.totalSupply(), 0);
    }

    function testOwnerCanMint() public {
        token.mint(bob, 25e18);

        assertEq(token.totalSupply(), 125e18);
        assertEq(token.balanceOf(bob), 25e18);
    }

    function testNonOwnerCannotMint() public {
        vm.prank(alice);
        vm.expectRevert(SimpleMintToken.NotOwner.selector);
        token.mint(bob, 1e18);
    }

    function testTransfer() public {
        vm.prank(alice);
        bool success = token.transfer(bob, 20e18);

        assertTrue(success);
        assertEq(token.balanceOf(alice), 80e18);
        assertEq(token.balanceOf(bob), 20e18);
    }

    function testApproveAndTransferFrom() public {
        vm.prank(alice);
        bool approved = token.approve(charlie, 30e18);
        assertTrue(approved);
        assertEq(token.allowance(alice, charlie), 30e18);

        vm.prank(charlie);
        bool success = token.transferFrom(alice, bob, 18e18);
        assertTrue(success);

        assertEq(token.balanceOf(alice), 82e18);
        assertEq(token.balanceOf(bob), 18e18);
        assertEq(token.allowance(alice, charlie), 12e18);
    }

    function testMintRevertsForZeroAddress() public {
        vm.expectRevert(SimpleMintToken.InvalidReceiver.selector);
        token.mint(address(0), 10e18);
    }

    function testTransferRevertsForInsufficientBalance() public {
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(SimpleMintToken.InsufficientBalance.selector, bob, 0, 1e18)
        );
        token.transfer(alice, 1e18);
    }

    function testTransferRevertsForZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert(SimpleMintToken.InvalidReceiver.selector);
        token.transfer(address(0), 1e18);
    }

    function testApproveRevertsForZeroSpender() public {
        vm.prank(alice);
        vm.expectRevert(SimpleMintToken.InvalidSpender.selector);
        token.approve(address(0), 1e18);
    }

    function testTransferFromRevertsForInsufficientAllowance() public {
        vm.prank(alice);
        token.approve(charlie, 5e18);

        vm.prank(charlie);
        vm.expectRevert(
            abi.encodeWithSelector(
                SimpleMintToken.InsufficientAllowance.selector,
                charlie,
                5e18,
                8e18
            )
        );
        token.transferFrom(alice, bob, 8e18);
    }
}
