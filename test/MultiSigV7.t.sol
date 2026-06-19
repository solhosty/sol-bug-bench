// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MultiSigV7.sol";

contract MockTarget {
    uint256 public calls;
    uint256 public lastValue;

    function ping() external payable {
        calls += 1;
        lastValue = msg.value;
    }
}

contract MultiSigV7Test is Test {
    MultiSigV7 public wallet;
    MockTarget public target;

    address public owner1;
    address public owner2;
    address public owner3;
    address public nonOwner;

    function setUp() public {
        owner1 = makeAddr("owner1");
        owner2 = makeAddr("owner2");
        owner3 = makeAddr("owner3");
        nonOwner = makeAddr("nonOwner");

        address[] memory walletOwners = new address[](3);
        walletOwners[0] = owner1;
        walletOwners[1] = owner2;
        walletOwners[2] = owner3;

        wallet = new MultiSigV7(walletOwners, 2);
        target = new MockTarget();
    }

    function testDeploymentOwnersAndThreshold() public view {
        assertEq(wallet.numConfirmationsRequired(), 2);
        assertEq(wallet.isOwner(owner1), true);
        assertEq(wallet.isOwner(owner2), true);
        assertEq(wallet.isOwner(owner3), true);
        assertEq(wallet.isOwner(nonOwner), false);

        address[] memory storedOwners = wallet.getOwners();
        assertEq(storedOwners.length, 3);
        assertEq(storedOwners[0], owner1);
        assertEq(storedOwners[1], owner2);
        assertEq(storedOwners[2], owner3);
    }

    function testSubmitConfirmExecuteHappyPath() public {
        vm.deal(address(wallet), 1 ether);

        vm.prank(owner1);
        wallet.submitTransaction(address(target), 1 ether, abi.encodeWithSignature("ping()"));

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        wallet.executeTransaction(0);

        assertEq(address(target).balance, 1 ether);
        assertEq(target.calls(), 1);
        assertEq(target.lastValue(), 1 ether);
    }

    function test_RevertWhen_ExecuteBeforeThreshold() public {
        vm.deal(address(wallet), 1 ether);

        vm.prank(owner1);
        wallet.submitTransaction(address(target), 1 ether, abi.encodeWithSignature("ping()"));

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        vm.expectRevert("Cannot execute transaction");
        wallet.executeTransaction(0);
    }

    function test_RevertWhen_NonOwnerSubmitsOrConfirms() public {
        vm.prank(nonOwner);
        vm.expectRevert("Not owner");
        wallet.submitTransaction(address(target), 0, "");

        vm.prank(owner1);
        wallet.submitTransaction(address(target), 0, "");

        vm.prank(nonOwner);
        vm.expectRevert("Not owner");
        wallet.confirmTransaction(0);
    }

    function testRevokeConfirmation() public {
        vm.prank(owner1);
        wallet.submitTransaction(address(target), 0, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        wallet.revokeConfirmation(0);

        (,,, bool executed, uint256 numConfirmations) = wallet.transactions(0);
        assertEq(executed, false);
        assertEq(numConfirmations, 0);
        assertEq(wallet.isConfirmed(0, owner1), false);
    }

    function test_RevertWhen_DoubleExecute() public {
        vm.deal(address(wallet), 1 ether);

        vm.prank(owner1);
        wallet.submitTransaction(address(target), 1 ether, abi.encodeWithSignature("ping()"));

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        wallet.executeTransaction(0);

        vm.prank(owner2);
        vm.expectRevert("Transaction already executed");
        wallet.executeTransaction(0);
    }
}
