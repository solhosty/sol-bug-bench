// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/BurnToken.sol";

contract BurnTokenTest is Test {
    BurnToken internal token;

    address internal owner;
    address internal alice;
    address internal bob;

    uint256 internal constant INITIAL_SUPPLY = 1_000_000 ether;

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        token = new BurnToken("Burn Token", "BURN", INITIAL_SUPPLY);
        token.transfer(alice, 1_000 ether);
    }

    function testInitialSupplyMintedToDeployer() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - 1_000 ether);
        assertEq(token.balanceOf(alice), 1_000 ether);
    }

    function testBurnReducesBalanceAndTotalSupply() public {
        uint256 burnAmount = 250 ether;
        uint256 initialSupply = token.totalSupply();
        uint256 initialBalance = token.balanceOf(alice);

        vm.prank(alice);
        token.burn(burnAmount);

        assertEq(token.balanceOf(alice), initialBalance - burnAmount);
        assertEq(token.totalSupply(), initialSupply - burnAmount);
    }

    function testBurnFromWithAllowance() public {
        uint256 burnAmount = 400 ether;
        uint256 initialSupply = token.totalSupply();

        vm.prank(alice);
        token.approve(bob, burnAmount);

        vm.prank(bob);
        token.burnFrom(alice, burnAmount);

        assertEq(token.balanceOf(alice), 1_000 ether - burnAmount);
        assertEq(token.totalSupply(), initialSupply - burnAmount);
        assertEq(token.allowance(alice, bob), 0);
    }

    function testBurnFromWithoutAllowanceReverts() public {
        uint256 burnAmount = 100 ether;

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)",
                bob,
                0,
                burnAmount
            )
        );
        token.burnFrom(alice, burnAmount);
    }

    function testBurnMoreThanBalanceReverts() public {
        uint256 burnAmount = 2_000 ether;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(address,uint256,uint256)",
                alice,
                1_000 ether,
                burnAmount
            )
        );
        token.burn(burnAmount);
    }
}
