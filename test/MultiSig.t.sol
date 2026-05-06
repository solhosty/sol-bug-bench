// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MultiSig.sol";

contract MultiSigTest is Test {
    MultiSig internal multiSig;

    address internal owner1 = address(1);
    address internal owner2 = address(2);
    address internal owner3 = address(3);
    address internal nonOwner = address(99);

    function setUp() public {
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        multiSig = new MultiSig(owners, 2);
        vm.deal(address(multiSig), 10 ether);
    }

    function testDeployment() public view {
        assertEq(multiSig.required(), 2);
        assertEq(multiSig.owners(0), owner1);
        assertEq(multiSig.owners(1), owner2);
        assertEq(multiSig.owners(2), owner3);
        assertEq(multiSig.isOwner(owner1), true);
        assertEq(multiSig.isOwner(owner2), true);
        assertEq(multiSig.isOwner(owner3), true);
    }

    function testSubmitConfirmExecute() public {
        address receiver = makeAddr("receiver");

        vm.prank(owner1);
        multiSig.submitTransaction(receiver, 1 ether, "");

        vm.prank(owner1);
        multiSig.confirmTransaction(0);

        vm.prank(owner2);
        multiSig.confirmTransaction(0);

        uint256 balanceBefore = receiver.balance;

        multiSig.executeTransaction(0);

        assertEq(receiver.balance, balanceBefore + 1 ether);
    }

    function testRevertNonOwnerSubmit() public {
        vm.prank(nonOwner);
        vm.expectRevert(bytes("not owner"));
        multiSig.submitTransaction(address(7), 1 ether, "");
    }

    function testRevertNonOwnerConfirm() public {
        vm.prank(owner1);
        multiSig.submitTransaction(address(7), 1 ether, "");

        vm.prank(nonOwner);
        vm.expectRevert(bytes("not owner"));
        multiSig.confirmTransaction(0);
    }

    function testRevertExecuteInsufficientConfirmations() public {
        vm.prank(owner1);
        multiSig.submitTransaction(address(7), 1 ether, "");

        vm.prank(owner1);
        multiSig.confirmTransaction(0);

        vm.expectRevert(bytes("cannot execute tx"));
        multiSig.executeTransaction(0);
    }

    function testRevokeConfirmation() public {
        vm.prank(owner1);
        multiSig.submitTransaction(address(7), 1 ether, "");

        vm.prank(owner1);
        multiSig.confirmTransaction(0);

        vm.prank(owner1);
        multiSig.revokeConfirmation(0);

        (, , , , uint256 numConfirmations) = multiSig.transactions(0);
        assertEq(multiSig.isConfirmed(0, owner1), false);
        assertEq(numConfirmations, 0);
    }
}
