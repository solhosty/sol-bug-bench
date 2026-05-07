// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleBurnTokenV8.sol";

contract SimpleBurnTokenV8Test is Test {
    SimpleBurnTokenV8 public token;
    address public owner;
    address public user1;
    address public burner;

    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        burner = makeAddr("burner");

        token = new SimpleBurnTokenV8("SimpleBurnToken", "SBT8", INITIAL_SUPPLY);
    }

    function testInitialSupplyAndBalance() public {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
    }

    function testBurnReducesBalanceAndTotalSupply() public {
        uint256 burnAmount = 100 * 10 ** 18;

        uint256 supplyBefore = token.totalSupply();
        uint256 ownerBalanceBefore = token.balanceOf(owner);

        token.burn(burnAmount);

        assertEq(token.totalSupply(), supplyBefore - burnAmount);
        assertEq(token.balanceOf(owner), ownerBalanceBefore - burnAmount);
    }

    function testBurnFromWithSufficientAllowance() public {
        uint256 transferAmount = 500 * 10 ** 18;
        uint256 burnAmount = 200 * 10 ** 18;

        token.transfer(user1, transferAmount);

        vm.prank(user1);
        token.approve(burner, burnAmount);

        uint256 supplyBefore = token.totalSupply();

        vm.prank(burner);
        token.burnFrom(user1, burnAmount);

        assertEq(token.balanceOf(user1), transferAmount - burnAmount);
        assertEq(token.totalSupply(), supplyBefore - burnAmount);
        assertEq(token.allowance(user1, burner), 0);
    }

    function test_RevertWhen_BurnFromWithoutAllowance() public {
        uint256 transferAmount = 500 * 10 ** 18;
        uint256 burnAmount = 200 * 10 ** 18;

        token.transfer(user1, transferAmount);

        vm.prank(burner);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)",
                burner,
                0,
                burnAmount
            )
        );
        token.burnFrom(user1, burnAmount);
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
