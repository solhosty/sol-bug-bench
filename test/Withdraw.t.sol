// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/LiquidityPool.sol";

contract WithdrawTest is Test {
    LiquidityPool public pool;
    PoolShare public shareToken;
    address public alice;
    address public bob;

    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdrawal(address indexed user, uint256 amount, uint256 shares);

    function setUp() public {
        pool = new LiquidityPool();
        shareToken = pool.shareToken();

        alice = makeAddr("alice");
        bob = makeAddr("bob");

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function test_Deposit_IncrementsBalance() public {
        vm.prank(alice);
        pool.deposit{value: 1 ether}();

        assertEq(shareToken.balanceOf(alice), 1 ether);
        assertEq(address(pool).balance, 1 ether);
    }

    function test_Deposit_EmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit Deposit(alice, 1 ether, 1 ether);

        vm.prank(alice);
        pool.deposit{value: 1 ether}();
    }

    function test_Deposit_MultipleDepositsAccumulate() public {
        vm.startPrank(alice);
        pool.deposit{value: 1 ether}();
        pool.deposit{value: 1 ether}();
        vm.stopPrank();

        uint256 expectedTotalShares = 1.5 ether;

        assertEq(shareToken.balanceOf(alice), expectedTotalShares);
        assertEq(address(pool).balance, 2 ether);
    }

    function test_Deposit_MultipleUsersIndependent() public {
        vm.prank(alice);
        pool.deposit{value: 1 ether}();

        vm.prank(bob);
        pool.deposit{value: 1 ether}();

        uint256 expectedBobShares = 0.5 ether;

        assertEq(shareToken.balanceOf(alice), 1 ether);
        assertEq(shareToken.balanceOf(bob), expectedBobShares);
        assertEq(address(pool).balance, 2 ether);
    }

    function test_Withdraw_DecrementsBalance() public {
        vm.startPrank(alice);
        pool.deposit{value: 2 ether}();
        shareToken.approve(address(pool), 1 ether);
        skip(pool.WITHDRAWAL_DELAY());

        pool.withdraw(1 ether);
        vm.stopPrank();

        assertEq(shareToken.balanceOf(alice), 1 ether);
    }

    function test_Withdraw_FullWithdraw() public {
        vm.startPrank(alice);
        pool.deposit{value: 1 ether}();
        shareToken.approve(address(pool), 1 ether);
        skip(pool.WITHDRAWAL_DELAY());

        pool.withdraw(1 ether);
        vm.stopPrank();

        assertEq(shareToken.balanceOf(alice), 0);
    }

    function test_Withdraw_TransfersEthToCaller() public {
        vm.startPrank(alice);
        pool.deposit{value: 1 ether}();
        shareToken.approve(address(pool), 1 ether);
        skip(pool.WITHDRAWAL_DELAY());

        uint256 balanceBefore = alice.balance;
        pool.withdraw(1 ether);
        vm.stopPrank();

        assertEq(alice.balance, balanceBefore + 1 ether);
    }

    function test_Withdraw_EmitsEvent() public {
        vm.startPrank(alice);
        pool.deposit{value: 1 ether}();
        shareToken.approve(address(pool), 1 ether);
        skip(pool.WITHDRAWAL_DELAY());

        vm.expectEmit(true, false, false, true);
        emit Withdrawal(alice, 1 ether, 1 ether);
        pool.withdraw(1 ether);
        vm.stopPrank();
    }

    function test_Withdraw_RevertsOnInsufficientBalance() public {
        vm.startPrank(alice);
        pool.deposit{value: 1 ether}();
        shareToken.approve(address(pool), 2 ether);
        skip(pool.WITHDRAWAL_DELAY());

        vm.expectRevert("Insufficient shares");
        pool.withdraw(2 ether);
        vm.stopPrank();
    }

    function test_Withdraw_RevertsWhenNoBalance() public {
        vm.prank(bob);
        vm.expectRevert("Insufficient shares");
        pool.withdraw(1 ether);
    }

    function test_Withdraw_RevertsBeforeDelay() public {
        vm.startPrank(alice);
        pool.deposit{value: 1 ether}();
        shareToken.approve(address(pool), 1 ether);

        vm.expectRevert("Withdrawal delay not met");
        pool.withdraw(1 ether);
        vm.stopPrank();
    }

    function test_DepositWithdrawCycle() public {
        vm.startPrank(alice);

        pool.deposit{value: 1 ether}();
        shareToken.approve(address(pool), 1 ether);
        skip(pool.WITHDRAWAL_DELAY());
        pool.withdraw(1 ether);

        pool.deposit{value: 2 ether}();
        shareToken.approve(address(pool), 2 ether);
        skip(pool.WITHDRAWAL_DELAY());
        pool.withdraw(2 ether);

        vm.stopPrank();

        assertEq(shareToken.balanceOf(alice), 0);
        assertEq(address(pool).balance, 0);
    }

    receive() external payable {}
}
