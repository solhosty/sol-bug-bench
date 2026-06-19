// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/BurnToken.sol";

contract BurnTokenTest is Test {
    BurnToken public token;

    address public owner;
    address public user;
    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;

    function setUp() public {
        owner = address(this);
        user = makeAddr("user");

        token = new BurnToken("BurnToken", "BURN", INITIAL_SUPPLY);
        assertTrue(token.transfer(user, 1_000e18));
    }

    function testInitialSupplyAndBalance() public {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - 1_000e18);
        assertEq(token.balanceOf(user), 1_000e18);
    }

    function testBurnReducesBalanceAndSupply() public {
        uint256 burnAmount = 500e18;
        uint256 initialOwnerBalance = token.balanceOf(owner);
        uint256 initialSupply = token.totalSupply();

        token.burn(burnAmount);

        assertEq(token.balanceOf(owner), initialOwnerBalance - burnAmount);
        assertEq(token.totalSupply(), initialSupply - burnAmount);
    }

    function testBurnFromWithAllowance() public {
        uint256 burnAmount = 400e18;
        uint256 initialUserBalance = token.balanceOf(user);
        uint256 initialSupply = token.totalSupply();

        vm.prank(user);
        assertTrue(token.approve(owner, burnAmount));

        token.burnFrom(user, burnAmount);

        assertEq(token.balanceOf(user), initialUserBalance - burnAmount);
        assertEq(token.totalSupply(), initialSupply - burnAmount);
        assertEq(token.allowance(user, owner), 0);
    }

    function test_RevertWhen_BurnFromWithoutAllowance() public {
        uint256 burnAmount = 1e18;

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)",
                owner,
                0,
                burnAmount
            )
        );
        token.burnFrom(user, burnAmount);
    }

    function test_RevertWhen_BurnMoreThanBalance() public {
        uint256 ownerBalance = token.balanceOf(owner);
        uint256 burnAmount = ownerBalance + 1;

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(address,uint256,uint256)",
                owner,
                ownerBalance,
                burnAmount
            )
        );
        token.burn(burnAmount);
    }
}
