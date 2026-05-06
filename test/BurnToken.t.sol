// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/BurnToken.sol";

contract BurnTokenTest is Test {
    BurnToken internal token;
    address internal alice;
    address internal bob;

    uint256 internal constant INITIAL_SUPPLY = 1_000_000e18;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        token = new BurnToken(INITIAL_SUPPLY);
        token.transfer(alice, 100_000e18);
    }

    function testInitialSupply() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(address(this)), 900_000e18);
        assertEq(token.balanceOf(alice), 100_000e18);
    }

    function testBurnReducesSupplyAndBalance() public {
        uint256 burnAmount = 25_000e18;
        uint256 oldSupply = token.totalSupply();

        vm.prank(alice);
        token.burn(burnAmount);

        assertEq(token.totalSupply(), oldSupply - burnAmount);
        assertEq(token.balanceOf(alice), 75_000e18);
    }

    function testRevertBurnExceedsBalance() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(address,uint256,uint256)",
                alice,
                100_000e18,
                100_001e18
            )
        );
        token.burn(100_001e18);
    }

    function testBurnFromWithAllowance() public {
        uint256 burnAmount = 40_000e18;
        uint256 oldSupply = token.totalSupply();

        vm.prank(alice);
        token.approve(bob, burnAmount);

        vm.prank(bob);
        token.burnFrom(alice, burnAmount);

        assertEq(token.balanceOf(alice), 60_000e18);
        assertEq(token.totalSupply(), oldSupply - burnAmount);
        assertEq(token.allowance(alice, bob), 0);
    }

    function testRevertBurnFromWithoutAllowance() public {
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)",
                bob,
                0,
                1e18
            )
        );
        token.burnFrom(alice, 1e18);
    }
}
