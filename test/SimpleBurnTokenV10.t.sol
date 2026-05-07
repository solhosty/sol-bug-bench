// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SimpleBurnTokenV10.sol";

contract SimpleBurnTokenV10Test is Test {
    SimpleBurnTokenV10 public token;

    address public owner;
    address public user1;
    address public spender;

    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        spender = makeAddr("spender");

        token = new SimpleBurnTokenV10("SimpleBurnToken", "SBT10", INITIAL_SUPPLY);
    }

    function testInitialSupplyMintedToDeployer() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.decimals(), 18);
    }

    function testTransfer() public {
        uint256 amount = 100 * 10 ** 18;

        bool success = token.transfer(user1, amount);

        assertTrue(success);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount);
        assertEq(token.balanceOf(user1), amount);
    }

    function testApproveAndTransferFrom() public {
        uint256 approved = 250 * 10 ** 18;
        uint256 transferAmount = 100 * 10 ** 18;

        bool approvedSuccess = token.approve(spender, approved);
        assertTrue(approvedSuccess);

        vm.prank(spender);
        bool success = token.transferFrom(owner, user1, transferAmount);

        assertTrue(success);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
        assertEq(token.balanceOf(user1), transferAmount);
        assertEq(token.allowance(owner, spender), approved - transferAmount);
    }

    function test_RevertWhen_ApproveNonZeroToNonZeroAllowance() public {
        token.approve(spender, 100 * 10 ** 18);

        vm.expectRevert("ERC20: approve from non-zero to non-zero allowance");
        token.approve(spender, 200 * 10 ** 18);
    }

    function testBurnReducesBalanceAndTotalSupply() public {
        uint256 burnAmount = 100 * 10 ** 18;
        uint256 supplyBefore = token.totalSupply();
        uint256 balanceBefore = token.balanceOf(owner);

        token.burn(burnAmount);

        assertEq(token.totalSupply(), supplyBefore - burnAmount);
        assertEq(token.balanceOf(owner), balanceBefore - burnAmount);
    }

    function test_RevertWhen_BurnMoreThanBalance() public {
        uint256 burnAmount = INITIAL_SUPPLY + 1;

        vm.expectRevert("ERC20: burn amount exceeds balance");
        token.burn(burnAmount);
    }

    function testBurnFromConsumesAllowanceAndReducesTotalSupply() public {
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

    function test_RevertWhen_BurnFromWithoutAllowance() public {
        uint256 transferAmount = 100 * 10 ** 18;
        uint256 burnAmount = 50 * 10 ** 18;

        token.transfer(user1, transferAmount);

        vm.prank(spender);
        vm.expectRevert("ERC20: insufficient allowance");
        token.burnFrom(user1, burnAmount);
    }
}
