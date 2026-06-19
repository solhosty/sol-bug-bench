// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MultiSigV4.sol";

contract MultiSigV4Test is Test {
    MultiSigV4 internal wallet;

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

        wallet = new MultiSigV4(owners, 2);
        vm.deal(address(wallet), 10 ether);
    }

    function testConstructorValidation_EmptyOwners() public {
        address[] memory owners = new address[](0);

        vm.expectRevert("owners required");
        new MultiSigV4(owners, 1);
    }

    function testConstructorValidation_ThresholdZero() public {
        address[] memory owners = new address[](1);
        owners[0] = owner1;

        vm.expectRevert("invalid threshold");
        new MultiSigV4(owners, 0);
    }

    function testConstructorValidation_ThresholdTooHigh() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;

        vm.expectRevert("invalid threshold");
        new MultiSigV4(owners, 3);
    }

    function testConstructorValidation_DuplicateOwners() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner1;

        vm.expectRevert("owner not unique");
        new MultiSigV4(owners, 2);
    }

    function testSubmitConfirmExecuteHappyPath() public {
        address recipient = makeAddr("recipient");

        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        uint256 balanceBefore = recipient.balance;

        vm.prank(owner3);
        wallet.executeTransaction(0);

        (, , , bool executed, uint256 numConfirmations) = wallet.transactions(0);
        assertTrue(executed);
        assertEq(numConfirmations, 2);
        assertEq(recipient.balance, balanceBefore + 1 ether);
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

    function testRevertWhen_NonOwnerSubmits() public {
        vm.prank(nonOwner);
        vm.expectRevert("not owner");
        wallet.submitTransaction(owner1, 1 ether, "");
    }

    function testRevertWhen_NonOwnerConfirms() public {
        vm.prank(owner1);
        wallet.submitTransaction(owner2, 1 ether, "");

        vm.prank(nonOwner);
        vm.expectRevert("not owner");
        wallet.confirmTransaction(0);
    }

    function testRevertWhen_ExecuteWithoutThreshold() public {
        vm.prank(owner1);
        wallet.submitTransaction(owner2, 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        vm.expectRevert("cannot execute tx");
        wallet.executeTransaction(0);
    }

    function testRevertWhen_DoubleExecute() public {
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

    function testRevertWhen_DuplicateConfirmation() public {
        vm.prank(owner1);
        wallet.submitTransaction(owner2, 0.25 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        vm.expectRevert("tx already confirmed");
        wallet.confirmTransaction(0);
    }
}
