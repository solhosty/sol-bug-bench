// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleBurnTokenV6.sol";

contract SimpleBurnTokenV6Test is Test {
    SimpleBurnTokenV6 public token;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        token = new SimpleBurnTokenV6();
        bool transferSuccess = token.transfer(user1, 1_000 * 10 ** token.decimals());
        assertTrue(transferSuccess);
    }

    function testInitialSupply() public {
        uint256 expectedSupply = 1_000_000 * 10 ** token.decimals();

        assertEq(token.totalSupply(), expectedSupply);
        assertEq(token.balanceOf(owner), expectedSupply - (1_000 * 10 ** token.decimals()));
        assertEq(token.balanceOf(user1), 1_000 * 10 ** token.decimals());
    }

    function testBurnReducesBalanceAndSupply() public {
        uint256 burnAmount = 250 * 10 ** token.decimals();
        uint256 supplyBefore = token.totalSupply();

        vm.prank(user1);
        token.burn(burnAmount);

        assertEq(token.balanceOf(user1), 750 * 10 ** token.decimals());
        assertEq(token.totalSupply(), supplyBefore - burnAmount);
    }

    function testBurnFromReducesAllowanceBalanceAndSupply() public {
        uint256 burnAmount = 400 * 10 ** token.decimals();
        uint256 allowanceAmount = 500 * 10 ** token.decimals();
        uint256 supplyBefore = token.totalSupply();

        vm.prank(user1);
        token.approve(user2, allowanceAmount);

        vm.prank(user2);
        token.burnFrom(user1, burnAmount);

        assertEq(token.balanceOf(user1), 600 * 10 ** token.decimals());
        assertEq(token.allowance(user1, user2), allowanceAmount - burnAmount);
        assertEq(token.totalSupply(), supplyBefore - burnAmount);
    }

    function test_RevertWhen_BurnFromInsufficientAllowance() public {
        uint256 approvedAmount = 100 * 10 ** token.decimals();
        uint256 burnAmount = 200 * 10 ** token.decimals();

        vm.prank(user1);
        token.approve(user2, approvedAmount);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)",
                user2,
                approvedAmount,
                burnAmount
            )
        );
        token.burnFrom(user1, burnAmount);
    }

    function test_RevertWhen_BurnInsufficientBalance() public {
        uint256 burnAmount = 1_001 * 10 ** token.decimals();

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(address,uint256,uint256)",
                user1,
                1_000 * 10 ** token.decimals(),
                burnAmount
            )
        );
        vm.prank(user1);
        token.burn(burnAmount);
    }
}
