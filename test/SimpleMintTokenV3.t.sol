// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleMintTokenV3.sol";

contract SimpleMintTokenV3Test is Test {
    SimpleMintTokenV3 public token;

    event Transfer(address indexed from, address indexed to, uint256 value);

    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        token = new SimpleMintTokenV3("Simple Mint Token V3", "SMTV3");
    }

    function testConstructorSetsInitialValues() public {
        assertEq(token.owner(), owner);
        assertEq(token.name(), "Simple Mint Token V3");
        assertEq(token.symbol(), "SMTV3");
        assertEq(token.decimals(), 18);
    }

    function testMintIncreasesBalanceAndTotalSupply() public {
        uint256 mintAmount = 50 ether;

        token.mint(user1, mintAmount);

        assertEq(token.balanceOf(user1), mintAmount);
        assertEq(token.totalSupply(), mintAmount);
    }

    function test_RevertWhen_NonOwnerMints() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1)
        );
        token.mint(user2, 1 ether);
    }

    function testTransferMovesTokensAndEmitsTransfer() public {
        uint256 mintAmount = 100 ether;
        uint256 transferAmount = 40 ether;

        token.mint(user1, mintAmount);

        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, transferAmount);

        vm.prank(user1);
        bool success = token.transfer(user2, transferAmount);

        assertTrue(success);
        assertEq(token.balanceOf(user1), mintAmount - transferAmount);
        assertEq(token.balanceOf(user2), transferAmount);
    }

    function testApproveAndTransferFrom() public {
        uint256 mintAmount = 100 ether;
        uint256 approvedAmount = 70 ether;
        uint256 spendAmount = 30 ether;

        token.mint(user1, mintAmount);

        vm.prank(user1);
        bool approved = token.approve(user2, approvedAmount);

        assertTrue(approved);
        assertEq(token.allowance(user1, user2), approvedAmount);

        vm.prank(user2);
        bool transferred = token.transferFrom(user1, user2, spendAmount);

        assertTrue(transferred);
        assertEq(token.balanceOf(user1), mintAmount - spendAmount);
        assertEq(token.balanceOf(user2), spendAmount);
        assertEq(token.allowance(user1, user2), approvedAmount - spendAmount);
    }

    function test_RevertWhen_TransferFromInsufficientAllowance() public {
        uint256 mintAmount = 100 ether;

        token.mint(user1, mintAmount);

        vm.prank(user1);
        token.approve(user2, 10 ether);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)",
                user2,
                10 ether,
                20 ether
            )
        );
        token.transferFrom(user1, user2, 20 ether);
    }

}
