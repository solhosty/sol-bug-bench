// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MultiSigV5.sol";

contract MultiSigV5Test is Test {
    MultiSigV5 internal wallet;

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

        wallet = new MultiSigV5(owners, 2);
        vm.deal(address(wallet), 10 ether);
    }

    function testDeployState() public {
        assertTrue(wallet.isOwner(owner1));
        assertTrue(wallet.isOwner(owner2));
        assertTrue(wallet.isOwner(owner3));
        assertEq(wallet.getOwnersCount(), 3);
        assertEq(wallet.threshold(), 2);
    }

    function testConstructorValidation_EmptyOwners() public {
        address[] memory owners = new address[](0);

        vm.expectRevert("owners required");
        new MultiSigV5(owners, 1);
    }

    function testConstructorValidation_ThresholdZero() public {
        address[] memory owners = new address[](1);
        owners[0] = owner1;

        vm.expectRevert("invalid threshold");
        new MultiSigV5(owners, 0);
    }

    function testConstructorValidation_ThresholdTooHigh() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;

        vm.expectRevert("invalid threshold");
        new MultiSigV5(owners, 3);
    }

    function testSubmitConfirmExecuteTransaction() public {
        address recipient = makeAddr("recipient");

        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(owner3);
        wallet.executeTransaction(0);

        (, , , bool executed, uint256 numConfirmations) = wallet.transactions(0);
        assertTrue(executed);
        assertEq(numConfirmations, 2);
        assertEq(recipient.balance, recipientBalanceBefore + 1 ether);
    }

    function testRevokeConfirmation() public {
        vm.prank(owner1);
        wallet.submitTransaction(owner3, 0.5 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        assertTrue(wallet.isConfirmed(0, owner1));

        vm.prank(owner1);
        wallet.revokeConfirmation(0);

        (, , , , uint256 numConfirmations) = wallet.transactions(0);
        assertFalse(wallet.isConfirmed(0, owner1));
        assertEq(numConfirmations, 0);
    }

    function test_RevertWhen_NonOwnerSubmits() public {
        vm.prank(nonOwner);
        vm.expectRevert("not owner");
        wallet.submitTransaction(owner1, 1 ether, "");
    }

    function test_RevertWhen_NonOwnerConfirms() public {
        vm.prank(owner1);
        wallet.submitTransaction(owner2, 1 ether, "");

        vm.prank(nonOwner);
        vm.expectRevert("not owner");
        wallet.confirmTransaction(0);
    }

    function test_RevertWhen_ExecuteWithoutThreshold() public {
        vm.prank(owner1);
        wallet.submitTransaction(owner2, 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        vm.expectRevert("cannot execute tx");
        wallet.executeTransaction(0);
    }

    function test_RevertWhen_RevokeWithoutConfirmation() public {
        vm.prank(owner1);
        wallet.submitTransaction(owner3, 0.5 ether, "");

        vm.prank(owner1);
        vm.expectRevert("tx not confirmed");
        wallet.revokeConfirmation(0);
    }

    function test_RevertWhen_DoubleExecute() public {
        vm.prank(owner1);
        wallet.submitTransaction(owner2, 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        vm.prank(owner3);
        wallet.executeTransaction(0);

        vm.prank(owner1);
        vm.expectRevert("tx already executed");
        wallet.executeTransaction(0);
    }

    function test_RevertWhen_DuplicateConfirmation() public {
        vm.prank(owner1);
        wallet.submitTransaction(owner2, 0.25 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        vm.expectRevert("tx already confirmed");
        wallet.confirmTransaction(0);
    }
}
