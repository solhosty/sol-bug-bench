// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MultiSig.sol";

contract MultiSigTest is Test {
    MultiSig internal wallet;

    address internal owner1;
    address internal owner2;
    address internal owner3;
    address internal nonOwner;

    function setUp() public {
        owner1 = makeAddr("owner1");
        owner2 = makeAddr("owner2");
        owner3 = makeAddr("owner3");
        nonOwner = makeAddr("nonOwner");

        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        wallet = new MultiSig(owners, 2);
        vm.deal(address(wallet), 10 ether);
    }

    function testDeployment() public view {
        assertEq(wallet.required(), 2);
        assertTrue(wallet.isOwner(owner1));
        assertTrue(wallet.isOwner(owner2));
        assertTrue(wallet.isOwner(owner3));
        assertEq(wallet.getTransactionCount(), 0);
        assertEq(address(wallet).balance, 10 ether);
    }

    function testSubmitConfirmExecute() public {
        address recipient = makeAddr("recipient");
        uint256 value = 1 ether;

        vm.prank(owner1);
        wallet.submitTransaction(recipient, value, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        vm.prank(owner3);
        wallet.executeTransaction(0);

        (, , , bool executed, uint256 numConfirmations) = wallet.transactions(0);
        assertTrue(executed);
        assertEq(numConfirmations, 2);
        assertEq(recipient.balance, value);
    }

    function testRevertNonOwnerSubmit() public {
        vm.prank(nonOwner);
        vm.expectRevert("not owner");
        wallet.submitTransaction(makeAddr("recipient"), 1 ether, "");
    }

    function testRevertNonOwnerConfirm() public {
        vm.prank(owner1);
        wallet.submitTransaction(makeAddr("recipient"), 1 ether, "");

        vm.prank(nonOwner);
        vm.expectRevert("not owner");
        wallet.confirmTransaction(0);
    }

    function testRevertExecuteInsufficientConfirmations() public {
        vm.prank(owner1);
        wallet.submitTransaction(makeAddr("recipient"), 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        vm.expectRevert("cannot execute tx");
        wallet.executeTransaction(0);
    }

    function testRevokeConfirmation() public {
        vm.prank(owner1);
        wallet.submitTransaction(makeAddr("recipient"), 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);
        assertTrue(wallet.isConfirmed(0, owner1));

        vm.prank(owner1);
        wallet.revokeConfirmation(0);

        (, , , , uint256 numConfirmations) = wallet.transactions(0);
        assertEq(numConfirmations, 0);
        assertFalse(wallet.isConfirmed(0, owner1));
    }
}
