// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MultiSig.sol";

contract Receiver {
    receive() external payable {}
}

contract MultiSigTest is Test {
    MultiSig public wallet;
    address public owner1;
    address public owner2;
    address public owner3;
    address public nonOwner;

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
        assertEq(wallet.owners(0), owner1);
        assertEq(wallet.owners(1), owner2);
        assertEq(wallet.owners(2), owner3);
        assertTrue(wallet.isOwner(owner1));
        assertTrue(wallet.isOwner(owner2));
        assertTrue(wallet.isOwner(owner3));
        assertEq(wallet.getTransactionCount(), 0);
        assertEq(address(wallet).balance, 10 ether);
    }

    function testSubmitConfirmExecute() public {
        Receiver recipient = new Receiver();
        uint256 amount = 1 ether;

        vm.prank(owner1);
        wallet.submitTransaction(address(recipient), amount, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        uint256 receiverBefore = address(recipient).balance;
        uint256 walletBefore = address(wallet).balance;

        vm.prank(owner3);
        wallet.executeTransaction(0);

        assertEq(address(recipient).balance, receiverBefore + amount);
        assertEq(address(wallet).balance, walletBefore - amount);

        (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        ) = wallet.transactions(0);
        assertEq(to, address(recipient));
        assertEq(value, amount);
        assertEq(data.length, 0);
        assertTrue(executed);
        assertEq(numConfirmations, 2);
    }

    function testRevertNonOwnerSubmit() public {
        vm.prank(nonOwner);
        vm.expectRevert("not owner");
        wallet.submitTransaction(nonOwner, 1 ether, "");
    }

    function testRevertNonOwnerConfirm() public {
        vm.prank(owner1);
        wallet.submitTransaction(nonOwner, 1 ether, "");

        vm.prank(nonOwner);
        vm.expectRevert("not owner");
        wallet.confirmTransaction(0);
    }

    function testRevertExecuteInsufficientConfirmations() public {
        vm.prank(owner1);
        wallet.submitTransaction(nonOwner, 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        vm.expectRevert("cannot execute tx");
        wallet.executeTransaction(0);
    }

    function testRevokeConfirmation() public {
        vm.prank(owner1);
        wallet.submitTransaction(nonOwner, 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        (, , , , uint256 confirmationsBefore) = wallet.transactions(0);
        assertEq(confirmationsBefore, 1);
        assertTrue(wallet.isConfirmed(0, owner1));

        vm.prank(owner1);
        wallet.revokeConfirmation(0);

        (, , , , uint256 confirmationsAfter) = wallet.transactions(0);
        assertEq(confirmationsAfter, 0);
        assertFalse(wallet.isConfirmed(0, owner1));
    }
}
