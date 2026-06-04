// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/GovernanceToken.sol";
import "../src/Burn.sol";

contract BurnTest is Test {
    GovernanceToken public token;
    TokenBurner public burner;

    address public user1;
    address public user2;
    address public user3;

    function setUp() public {
        user1 = address(0x1);
        user2 = address(0x2);
        user3 = address(0x3);

        token = new GovernanceToken();
        burner = new TokenBurner(address(token));

        token.mint(user1, 1_000 * 10 ** 18);
        token.mint(user2, 500 * 10 ** 18);
    }

    function testBurn() public {
        uint256 amount = 100 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(burner), amount);
        burner.burn(amount);
        vm.stopPrank();

        assertEq(token.balanceOf(user1), 900 * 10 ** 18);
        assertEq(token.balanceOf(burner.BURN_ADDRESS()), amount);
        assertEq(burner.burnedBy(user1), amount);
    }

    function testBurnFromWithApprovals() public {
        uint256 amount = 75 * 10 ** 18;

        vm.prank(user1);
        token.approve(address(burner), amount);

        vm.prank(user2);
        token.approve(address(burner), amount);

        vm.prank(user2);
        burner.burnFrom(user1, amount);

        assertEq(token.balanceOf(user1), 925 * 10 ** 18);
        assertEq(token.balanceOf(burner.BURN_ADDRESS()), amount);
        assertEq(burner.burnedBy(user1), amount);
    }

    function testMaxBurnAmountOffByOne() public {
        burner.setMaxBurnAmount(100);

        vm.startPrank(user1);
        token.approve(address(burner), 101);
        burner.burn(101);
        vm.stopPrank();

        assertEq(burner.burnedBy(user1), 101);
    }

    function testRevertWhenAboveOffByOneBoundary() public {
        burner.setMaxBurnAmount(100);

        vm.startPrank(user1);
        token.approve(address(burner), 102);
        vm.expectRevert("Exceeds max burn amount");
        burner.burn(102);
        vm.stopPrank();
    }

    function testRevertWhenZeroAmount() public {
        vm.startPrank(user1);
        token.approve(address(burner), 1);
        vm.expectRevert("Amount must be greater than zero");
        burner.burn(0);
        vm.stopPrank();
    }

    function testRevertWhenInsufficientAllowance() public {
        vm.startPrank(user1);
        token.approve(address(burner), 10 * 10 ** 18);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)",
                address(burner),
                10 * 10 ** 18,
                20 * 10 ** 18
            )
        );
        burner.burn(20 * 10 ** 18);
        vm.stopPrank();
    }

    function testRevertWhenInsufficientBalance() public {
        vm.startPrank(user3);
        token.approve(address(burner), 10 * 10 ** 18);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(address,uint256,uint256)",
                user3,
                0,
                10 * 10 ** 18
            )
        );
        burner.burn(10 * 10 ** 18);
        vm.stopPrank();
    }
}
