// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleBurnTokenV9.sol";

contract SimpleBurnTokenV9Test is Test {
    SimpleBurnTokenV9 public token;

    address public owner;
    address public user1;
    address public spender;

    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        spender = makeAddr("spender");

        token = new SimpleBurnTokenV9("SimpleBurnToken", "SBT9", INITIAL_SUPPLY);
    }

    function testMintOnDeploy() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.decimals(), 18);
    }

    function testTransfer() public {
        uint256 amount = 100 * 10 ** 18;

        token.transfer(user1, amount);

        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount);
        assertEq(token.balanceOf(user1), amount);
    }

    function testApproveAndTransferFrom() public {
        uint256 approved = 250 * 10 ** 18;
        uint256 transferAmount = 100 * 10 ** 18;

        token.approve(spender, approved);

        vm.prank(spender);
        token.transferFrom(owner, user1, transferAmount);

        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
        assertEq(token.balanceOf(user1), transferAmount);
        assertEq(token.allowance(owner, spender), approved - transferAmount);
    }

    function testBurnReducesBalanceAndSupply() public {
        uint256 burnAmount = 100 * 10 ** 18;

        uint256 supplyBefore = token.totalSupply();
        uint256 ownerBalanceBefore = token.balanceOf(owner);

        token.burn(burnAmount);

        assertEq(token.totalSupply(), supplyBefore - burnAmount);
        assertEq(token.balanceOf(owner), ownerBalanceBefore - burnAmount);
    }

    function testBurnFromWithAllowance() public {
        uint256 transferAmount = 500 * 10 ** 18;
        uint256 burnAmount = 200 * 10 ** 18;

        token.transfer(user1, transferAmount);

        vm.prank(user1);
        token.approve(spender, burnAmount);

        uint256 supplyBefore = token.totalSupply();

        vm.prank(spender);
        token.burnFrom(user1, burnAmount);

        assertEq(token.balanceOf(user1), transferAmount - burnAmount);
        assertEq(token.totalSupply(), supplyBefore - burnAmount);
        assertEq(token.allowance(user1, spender), 0);
    }

    function test_RevertWhen_BurnFromInsufficientAllowance() public {
        uint256 transferAmount = 500 * 10 ** 18;
        uint256 approvedAmount = 50 * 10 ** 18;
        uint256 burnAmount = 100 * 10 ** 18;

        token.transfer(user1, transferAmount);

        vm.prank(user1);
        token.approve(spender, approvedAmount);

        vm.prank(spender);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)",
                spender,
                approvedAmount,
                burnAmount
            )
        );
        token.burnFrom(user1, burnAmount);
    }

    function test_RevertWhen_BurnExceedsBalance() public {
        uint256 burnAmount = INITIAL_SUPPLY + 1;

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientBalance(address,uint256,uint256)",
                owner,
                INITIAL_SUPPLY,
                burnAmount
            )
        );
        token.burn(burnAmount);
    }
}
