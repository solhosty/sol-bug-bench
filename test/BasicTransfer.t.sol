// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/BasicTransfer.sol";

contract BasicTransferTest is Test {
    BasicTransfer public transferContract;
    address public user1;
    address public user2;

    function setUp() public {
        transferContract = new BasicTransfer();

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    function test_DepositIncreasesBalance() public {
        vm.prank(user1);
        transferContract.deposit{value: 1 ether}();

        assertEq(transferContract.balances(user1), 1 ether);
        assertEq(address(transferContract).balance, 1 ether);
    }

    function test_WithdrawSendsETH() public {
        vm.prank(user1);
        transferContract.deposit{value: 2 ether}();

        uint256 balanceBefore = user1.balance;

        vm.prank(user1);
        transferContract.withdraw(1 ether);

        assertEq(user1.balance, balanceBefore + 1 ether);
        assertEq(transferContract.balances(user1), 1 ether);
        assertEq(address(transferContract).balance, 1 ether);
    }

    function test_TransferMovesBalance() public {
        vm.prank(user1);
        transferContract.deposit{value: 1 ether}();

        vm.prank(user1);
        transferContract.transfer(user2, 0.4 ether);

        assertEq(transferContract.balances(user1), 0.6 ether);
        assertEq(transferContract.balances(user2), 0.4 ether);
    }

    function test_CannotWithdrawMoreThanBalance() public {
        vm.prank(user1);
        transferContract.deposit{value: 1 ether}();

        vm.prank(user1);
        vm.expectRevert("Insufficient balance");
        transferContract.withdraw(2 ether);
    }

    function test_CannotTransferToZeroAddress() public {
        vm.prank(user1);
        transferContract.deposit{value: 1 ether}();

        vm.prank(user1);
        vm.expectRevert("Invalid recipient");
        transferContract.transfer(address(0), 0.1 ether);
    }
}
