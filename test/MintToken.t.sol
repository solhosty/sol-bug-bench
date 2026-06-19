// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MintToken.sol";

contract MintTokenTest is Test {
    MintToken internal token;
    address internal owner;
    address internal alice;
    address internal bob;

    string internal constant TOKEN_NAME = "Mint Token";
    string internal constant TOKEN_SYMBOL = "MINT";

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        token = new MintToken(TOKEN_NAME, TOKEN_SYMBOL);
    }

    function testConstructorState() public {
        assertEq(token.name(), TOKEN_NAME);
        assertEq(token.symbol(), TOKEN_SYMBOL);
        assertEq(token.decimals(), 18);
        assertEq(token.owner(), owner);
        assertEq(token.totalSupply(), 0);
    }

    function testOwnerCanMint() public {
        uint256 mintAmount = 100 ether;

        token.mint(alice, mintAmount);

        assertEq(token.balanceOf(alice), mintAmount);
        assertEq(token.totalSupply(), mintAmount);
    }

    function testNonOwnerMintReverts() public {
        vm.prank(alice);
        vm.expectRevert("not owner");
        token.mint(bob, 1 ether);
    }

    function testTransfer() public {
        uint256 mintAmount = 50 ether;
        uint256 transferAmount = 15 ether;

        token.mint(alice, mintAmount);

        vm.prank(alice);
        bool success = token.transfer(bob, transferAmount);

        assertTrue(success);
        assertEq(token.balanceOf(alice), mintAmount - transferAmount);
        assertEq(token.balanceOf(bob), transferAmount);
    }

    function testApproveAndTransferFrom() public {
        uint256 mintAmount = 40 ether;
        uint256 allowanceAmount = 25 ether;
        uint256 spendAmount = 10 ether;

        token.mint(alice, mintAmount);

        vm.prank(alice);
        bool approveSuccess = token.approve(bob, allowanceAmount);
        assertTrue(approveSuccess);
        assertEq(token.allowance(alice, bob), allowanceAmount);

        vm.prank(bob);
        bool transferFromSuccess = token.transferFrom(alice, bob, spendAmount);

        assertTrue(transferFromSuccess);
        assertEq(token.balanceOf(alice), mintAmount - spendAmount);
        assertEq(token.balanceOf(bob), spendAmount);
        assertEq(token.allowance(alice, bob), allowanceAmount - spendAmount);
    }
}
