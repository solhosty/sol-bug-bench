// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MultiSigV2.sol";

contract MultiSigV2Test is Test {
    MultiSigV2 public wallet;

    address public owner1;
    address public owner2;
    address public owner3;
    address public nonOwner;
    address payable public recipient;

    function setUp() public {
        owner1 = makeAddr("owner1");
        owner2 = makeAddr("owner2");
        owner3 = makeAddr("owner3");
        nonOwner = makeAddr("nonOwner");
        recipient = payable(makeAddr("recipient"));

        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        wallet = new MultiSigV2(owners, 2);
    }

    function testInitialState() public {
        address[] memory owners = wallet.getOwners();

        assertEq(owners.length, 3);
        assertEq(owners[0], owner1);
        assertEq(owners[1], owner2);
        assertEq(owners[2], owner3);
        assertEq(wallet.threshold(), 2);
        assertEq(wallet.getTransactionCount(), 0);
    }

    function testReceiveEmitsDepositAndUpdatesBalance() public {
        vm.deal(owner1, 1 ether);

        vm.prank(owner1);
        (bool success,) = address(wallet).call{value: 0.4 ether}("");

        assertTrue(success);
        assertEq(address(wallet).balance, 0.4 ether);
    }

    function testSubmitConfirmAndExecuteHappyPath() public {
        vm.deal(address(wallet), 1 ether);

        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(recipient, 0.6 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(txId);

        vm.prank(owner2);
        wallet.confirmTransaction(txId);

        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(owner3);
        wallet.executeTransaction(txId);

        (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        ) = wallet.getTransaction(txId);

        assertEq(to, recipient);
        assertEq(value, 0.6 ether);
        assertEq(data.length, 0);
        assertTrue(executed);
        assertEq(numConfirmations, 2);
        assertEq(recipient.balance, recipientBalanceBefore + 0.6 ether);
    }

    function testRevokeConfirmation() public {
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(recipient, 0.1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(txId);
        assertTrue(wallet.isConfirmed(txId, owner1));

        vm.prank(owner1);
        wallet.revokeConfirmation(txId);

        (, , , , uint256 numConfirmations) = wallet.getTransaction(txId);
        assertEq(numConfirmations, 0);
        assertFalse(wallet.isConfirmed(txId, owner1));
    }

    function test_RevertWhen_BadThresholdZero() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;

        vm.expectRevert("invalid threshold");
        new MultiSigV2(owners, 0);
    }

    function test_RevertWhen_BadThresholdAboveOwnerCount() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;

        vm.expectRevert("invalid threshold");
        new MultiSigV2(owners, 3);
    }

    function test_RevertWhen_ZeroOwnerProvided() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = address(0);

        vm.expectRevert("invalid owner");
        new MultiSigV2(owners, 1);
    }

    function test_RevertWhen_DuplicateOwnerProvided() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner1;

        vm.expectRevert("owner not unique");
        new MultiSigV2(owners, 1);
    }

    function test_RevertWhen_NonOwnerSubmitTransaction() public {
        vm.prank(nonOwner);
        vm.expectRevert("not owner");
        wallet.submitTransaction(recipient, 0.1 ether, "");
    }

    function test_RevertWhen_NonOwnerConfirmTransaction() public {
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(recipient, 0.1 ether, "");

        vm.prank(nonOwner);
        vm.expectRevert("not owner");
        wallet.confirmTransaction(txId);
    }

    function test_RevertWhen_NonOwnerRevokeConfirmation() public {
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(recipient, 0.1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(txId);

        vm.prank(nonOwner);
        vm.expectRevert("not owner");
        wallet.revokeConfirmation(txId);
    }

    function test_RevertWhen_NonOwnerExecuteTransaction() public {
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(recipient, 0.1 ether, "");

        vm.prank(nonOwner);
        vm.expectRevert("not owner");
        wallet.executeTransaction(txId);
    }

    function test_RevertWhen_ThresholdNotMet() public {
        vm.deal(address(wallet), 1 ether);

        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(recipient, 0.2 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(txId);

        vm.prank(owner2);
        vm.expectRevert("cannot execute tx");
        wallet.executeTransaction(txId);
    }

    function test_RevertWhen_DoubleConfirm() public {
        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(recipient, 0.1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(txId);

        vm.prank(owner1);
        vm.expectRevert("tx already confirmed");
        wallet.confirmTransaction(txId);
    }

    function test_RevertWhen_ConfirmExecutedTransaction() public {
        vm.deal(address(wallet), 1 ether);

        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(recipient, 0.5 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(txId);
        vm.prank(owner2);
        wallet.confirmTransaction(txId);
        vm.prank(owner1);
        wallet.executeTransaction(txId);

        vm.prank(owner3);
        vm.expectRevert("tx already executed");
        wallet.confirmTransaction(txId);
    }

    function test_RevertWhen_ExecuteAlreadyExecutedTransaction() public {
        vm.deal(address(wallet), 1 ether);

        vm.prank(owner1);
        uint256 txId = wallet.submitTransaction(recipient, 0.3 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(txId);
        vm.prank(owner2);
        wallet.confirmTransaction(txId);
        vm.prank(owner2);
        wallet.executeTransaction(txId);

        vm.prank(owner1);
        vm.expectRevert("tx already executed");
        wallet.executeTransaction(txId);
    }
}
