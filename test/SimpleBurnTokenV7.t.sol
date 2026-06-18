// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleBurnTokenV7.sol";

contract SimpleBurnTokenV7Test is Test {
    SimpleBurnTokenV7 public token;

    address public owner;
    address public user1;
    address public user2;

    string internal constant TOKEN_NAME = "Simple Burn Token V7";
    string internal constant TOKEN_SYMBOL = "SBTV7";
    uint8 internal constant TOKEN_DECIMALS = 18;
    uint256 internal constant INITIAL_SUPPLY = 1_000_000 ether;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        token = new SimpleBurnTokenV7(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_DECIMALS,
            INITIAL_SUPPLY
        );
    }

    function testInitialSupplyAndMetadata() public {
        assertEq(token.name(), TOKEN_NAME);
        assertEq(token.symbol(), TOKEN_SYMBOL);
        assertEq(token.decimals(), TOKEN_DECIMALS);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
    }

    function testTransfer() public {
        uint256 amount = 500 ether;

        token.transfer(user1, amount);

        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount);
        assertEq(token.balanceOf(user1), amount);
    }

    function testApproveAndTransferFrom() public {
        uint256 approvedAmount = 800 ether;
        uint256 transferAmount = 300 ether;

        token.approve(user1, approvedAmount);

        vm.prank(user1);
        token.transferFrom(owner, user2, transferAmount);

        assertEq(token.balanceOf(user2), transferAmount);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
        assertEq(token.allowance(owner, user1), approvedAmount - transferAmount);
    }

    function testApproveRequiresZeroResetForNonZeroUpdate() public {
        token.approve(user1, 100 ether);

        vm.expectRevert("Reset allowance to zero first");
        token.approve(user1, 200 ether);

        token.approve(user1, 0);
        token.approve(user1, 200 ether);
        assertEq(token.allowance(owner, user1), 200 ether);
    }

    function testBurnReducesBalanceAndTotalSupply() public {
        uint256 burnAmount = 250 ether;
        uint256 totalSupplyBefore = token.totalSupply();
        uint256 ownerBalanceBefore = token.balanceOf(owner);

        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(owner, address(0), burnAmount);
        token.burn(burnAmount);

        assertEq(token.totalSupply(), totalSupplyBefore - burnAmount);
        assertEq(token.balanceOf(owner), ownerBalanceBefore - burnAmount);
    }

    function testBurnFromRespectsAllowance() public {
        uint256 transferAmount = 700 ether;
        uint256 approvedBurn = 300 ether;
        uint256 burnAmount = 200 ether;

        token.transfer(user1, transferAmount);

        vm.prank(user1);
        token.approve(owner, approvedBurn);

        uint256 totalSupplyBefore = token.totalSupply();

        token.burnFrom(user1, burnAmount);

        assertEq(token.balanceOf(user1), transferAmount - burnAmount);
        assertEq(token.totalSupply(), totalSupplyBefore - burnAmount);
        assertEq(token.allowance(user1, owner), approvedBurn - burnAmount);
    }

    function test_RevertWhen_BurnExceedsBalance() public {
        uint256 ownerBalance = token.balanceOf(owner);

        vm.expectRevert("Insufficient balance");
        token.burn(ownerBalance + 1);
    }

    function test_RevertWhen_BurnFromExceedsAllowance() public {
        uint256 transferAmount = 400 ether;
        uint256 approvedBurn = 100 ether;
        uint256 burnAmount = 150 ether;

        token.transfer(user1, transferAmount);

        vm.prank(user1);
        token.approve(owner, approvedBurn);

        vm.expectRevert("Insufficient allowance");
        token.burnFrom(user1, burnAmount);
    }
}
