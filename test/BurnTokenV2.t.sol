// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/BurnTokenV2.sol";

contract BurnTokenV2Test is Test {
    BurnTokenV2 public token;
    address public alice;
    address public bob;

    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        token = new BurnTokenV2("Burn Token V2", "BURNV2", INITIAL_SUPPLY);
    }

    function testInitialSupplyAndDeployerBalance() public {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(address(this)), INITIAL_SUPPLY);
    }

    function testBurnReducesBalanceAndTotalSupply() public {
        uint256 transferAmount = 200 * 10 ** 18;
        uint256 burnAmount = 50 * 10 ** 18;

        token.transfer(alice, transferAmount);

        vm.prank(alice);
        token.burn(burnAmount);

        assertEq(token.balanceOf(alice), transferAmount - burnAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - burnAmount);
    }

    function testBurnFromWithAllowance() public {
        uint256 transferAmount = 300 * 10 ** 18;
        uint256 burnAmount = 120 * 10 ** 18;

        token.transfer(alice, transferAmount);

        vm.prank(alice);
        token.approve(bob, burnAmount);

        vm.prank(bob);
        token.burnFrom(alice, burnAmount);

        assertEq(token.balanceOf(alice), transferAmount - burnAmount);
        assertEq(token.allowance(alice, bob), 0);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - burnAmount);
    }

    function test_RevertWhen_BurnFromWithoutAllowance() public {
        uint256 transferAmount = 100 * 10 ** 18;
        uint256 burnAmount = 10 * 10 ** 18;

        token.transfer(alice, transferAmount);

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

    function test_RevertWhen_BurnMoreThanBalance() public {
        uint256 balance = 25 * 10 ** 18;
        uint256 burnAmount = 30 * 10 ** 18;

        token.transfer(alice, balance);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(address,uint256,uint256)",
                alice,
                balance,
                burnAmount
            )
        );
        token.burn(burnAmount);
    }
}
