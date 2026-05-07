// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SimpleMultiSigV10.sol";

contract MultiSigTarget {
    uint256 public calls;
    uint256 public lastValue;

    function ping() external payable {
        calls += 1;
        lastValue = msg.value;
    }
}

contract SimpleMultiSigV10Test is Test {
    SimpleMultiSigV10 public wallet;
    MultiSigTarget public target;

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

        wallet = new SimpleMultiSigV10(walletOwners, 2);
        target = new MultiSigTarget();
    }

    function testDeploymentValidationAndState() public {
        assertEq(wallet.numConfirmationsRequired(), 2);
        assertTrue(wallet.isOwner(owner1));
        assertTrue(wallet.isOwner(owner2));
        assertTrue(wallet.isOwner(owner3));
        assertFalse(wallet.isOwner(nonOwner));

        address[] memory owners = wallet.getOwners();
        assertEq(owners.length, 3);
        assertEq(owners[0], owner1);
        assertEq(owners[1], owner2);
        assertEq(owners[2], owner3);
    }

    function test_RevertWhen_DeployWithEmptyOwners() public {
        address[] memory walletOwners = new address[](0);

        vm.expectRevert(bytes("Owners required"));
        new SimpleMultiSigV10(walletOwners, 1);
    }

    function test_RevertWhen_DeployWithZeroOwner() public {
        address[] memory walletOwners = new address[](2);
        walletOwners[0] = owner1;
        walletOwners[1] = address(0);

        vm.expectRevert(bytes("Invalid owner"));
        new SimpleMultiSigV10(walletOwners, 1);
    }

    function test_RevertWhen_DeployWithDuplicateOwner() public {
        address[] memory walletOwners = new address[](2);
        walletOwners[0] = owner1;
        walletOwners[1] = owner1;

        vm.expectRevert(bytes("Owner not unique"));
        new SimpleMultiSigV10(walletOwners, 1);
    }

    function test_RevertWhen_DeployWithInvalidThreshold() public {
        address[] memory walletOwners = new address[](2);
        walletOwners[0] = owner1;
        walletOwners[1] = owner2;

        vm.expectRevert(bytes("Invalid threshold"));
        new SimpleMultiSigV10(walletOwners, 0);

        vm.expectRevert(bytes("Threshold exceeds owners"));
        new SimpleMultiSigV10(walletOwners, 3);
    }

    function testSubmitConfirmExecuteHappyPath() public {
        vm.deal(address(wallet), 1 ether);

        vm.prank(owner1);
        wallet.submitTransaction(address(target), 0, abi.encodeWithSignature("ping()"));

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        vm.prank(owner3);
        wallet.executeTransaction(0);

        (,,, bool executed, uint256 numConfirmations) = wallet.transactions(0);
        assertTrue(executed);
        assertEq(numConfirmations, 2);
        assertEq(target.calls(), 1);
    }

    function test_RevertWhen_ExecuteBelowThreshold() public {
        vm.prank(owner1);
        wallet.submitTransaction(address(target), 0, abi.encodeWithSignature("ping()"));

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        vm.expectRevert(bytes("Cannot execute transaction"));
        wallet.executeTransaction(0);
    }

    function test_RevertWhen_DoubleConfirm() public {
        vm.prank(owner1);
        wallet.submitTransaction(address(target), 0, abi.encodeWithSignature("ping()"));

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        vm.expectRevert(bytes("Transaction already confirmed"));
        wallet.confirmTransaction(0);
    }

    function testRevokeConfirmation() public {
        vm.prank(owner1);
        wallet.submitTransaction(address(target), 0, abi.encodeWithSignature("ping()"));

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        wallet.revokeConfirmation(0);

        (,,,, uint256 numConfirmations) = wallet.transactions(0);
        assertEq(numConfirmations, 1);
        assertFalse(wallet.isConfirmed(0, owner2));

        vm.prank(owner1);
        vm.expectRevert(bytes("Cannot execute transaction"));
        wallet.executeTransaction(0);
    }

    function test_RevertWhen_NonOwnerSubmitConfirmExecute() public {
        vm.prank(owner1);
        wallet.submitTransaction(address(target), 0, abi.encodeWithSignature("ping()"));

        vm.prank(nonOwner);
        vm.expectRevert(bytes("Not owner"));
        wallet.submitTransaction(address(target), 0, abi.encodeWithSignature("ping()"));

        vm.prank(nonOwner);
        vm.expectRevert(bytes("Not owner"));
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        vm.prank(nonOwner);
        vm.expectRevert(bytes("Not owner"));
        wallet.executeTransaction(0);
    }

    function test_RevertWhen_ExecuteAlreadyExecutedTransaction() public {
        vm.prank(owner1);
        wallet.submitTransaction(address(target), 0, abi.encodeWithSignature("ping()"));

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        wallet.executeTransaction(0);

        vm.prank(owner2);
        vm.expectRevert(bytes("Transaction already executed"));
        wallet.executeTransaction(0);
    }

    function testEthTransferViaExecutedTransaction() public {
        address receiver = makeAddr("receiver");
        vm.deal(address(wallet), 3 ether);

        vm.prank(owner1);
        wallet.submitTransaction(receiver, 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        uint256 receiverBefore = receiver.balance;

        vm.prank(owner3);
        wallet.executeTransaction(0);

        assertEq(receiver.balance, receiverBefore + 1 ether);
        assertEq(address(wallet).balance, 2 ether);
    }
}
