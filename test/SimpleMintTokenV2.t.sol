// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleMintTokenV2.sol";

contract SimpleMintTokenV2Test is Test {
    SimpleMintTokenV2 public token;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        token = new SimpleMintTokenV2();
    }

    function testConstructorState() public {
        assertEq(token.owner(), owner);
        assertEq(token.name(), "Simple Mint Token V2");
        assertEq(token.symbol(), "SMTV2");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
    }

    function testMintIncreasesBalanceAndTotalSupply() public {
        uint256 mintAmount = 1000 ether;

        token.mint(user1, mintAmount);

        assertEq(token.balanceOf(user1), mintAmount);
        assertEq(token.totalSupply(), mintAmount);
    }

    function test_RevertWhen_NonOwnerMints() public {
        vm.prank(user1);
        vm.expectRevert("Not owner");
        token.mint(user2, 1 ether);
    }

    function testTransferSuccessAndEvent() public {
        uint256 mintAmount = 10 ether;
        uint256 transferAmount = 4 ether;

        token.mint(user1, mintAmount);

        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit SimpleMintTokenV2.Transfer(user1, user2, transferAmount);
        bool success = token.transfer(user2, transferAmount);

        assertTrue(success);
        assertEq(token.balanceOf(user1), mintAmount - transferAmount);
        assertEq(token.balanceOf(user2), transferAmount);
    }

    function testApproveAndTransferFromSuccess() public {
        uint256 mintAmount = 20 ether;
        uint256 spendAmount = 7 ether;

        token.mint(user1, mintAmount);

        vm.prank(user1);
        bool approved = token.approve(user2, spendAmount);
        assertTrue(approved);
        assertEq(token.allowance(user1, user2), spendAmount);

        vm.prank(user2);
        bool transferred = token.transferFrom(user1, user2, spendAmount);

        assertTrue(transferred);
        assertEq(token.balanceOf(user1), mintAmount - spendAmount);
        assertEq(token.balanceOf(user2), spendAmount);
        assertEq(token.allowance(user1, user2), 0);
    }

    function test_RevertWhen_TransferFromInsufficientAllowance() public {
        uint256 mintAmount = 15 ether;

        token.mint(user1, mintAmount);

        vm.prank(user1);
        token.approve(user2, 1 ether);

        vm.prank(user2);
        vm.expectRevert("Insufficient allowance");
        token.transferFrom(user1, user2, 2 ether);
    }
}
