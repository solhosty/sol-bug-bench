// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MultiSigWallet.sol";

contract CallTarget {
    uint256 public storedValue;

    function setValue(uint256 newValue) external payable {
        storedValue = newValue;
    }
}

contract MultiSigWalletTest is Test {
    MultiSigWallet internal wallet;
    CallTarget internal target;

    address internal owner1;
    address internal owner2;
    address internal owner3;
    address internal nonOwner;
    address payable internal receiver;

    function setUp() public {
        owner1 = makeAddr("owner1");
        owner2 = makeAddr("owner2");
        owner3 = makeAddr("owner3");
        nonOwner = makeAddr("nonOwner");
        receiver = payable(makeAddr("receiver"));

        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        wallet = new MultiSigWallet(owners, 2);
        target = new CallTarget();
    }

    function _submitBasicTx(
        address txTarget,
        uint256 value,
        bytes memory data
    ) internal returns (uint256) {
        vm.prank(owner1);
        return wallet.submitTransaction(txTarget, value, data);
    }

    function _confirmBy(address owner, uint256 txIndex) internal {
        vm.prank(owner);
        wallet.confirmTransaction(txIndex);
    }

    function testSubmitAndExecuteEthTransfer() public {
        vm.deal(address(wallet), 1 ether);

        uint256 txIndex = _submitBasicTx(receiver, 0.4 ether, "");

        _confirmBy(owner1, txIndex);
        _confirmBy(owner2, txIndex);

        uint256 receiverBefore = receiver.balance;
        vm.prank(owner3);
        wallet.executeTransaction(txIndex);

        assertEq(receiver.balance, receiverBefore + 0.4 ether);
        (, , , bool executed, ) = wallet.transactions(txIndex);
        assertTrue(executed);
    }

    function testExecuteArbitraryCall() public {
        bytes memory callData = abi.encodeWithSignature("setValue(uint256)", 42);
        uint256 txIndex = _submitBasicTx(address(target), 0, callData);

        _confirmBy(owner1, txIndex);
        _confirmBy(owner2, txIndex);

        vm.prank(owner1);
        wallet.executeTransaction(txIndex);

        assertEq(target.storedValue(), 42);
    }

    function test_RevertWhen_NonOwnerSubmits() public {
        vm.prank(nonOwner);
        vm.expectRevert("Not owner");
        wallet.submitTransaction(receiver, 0, "");
    }

    function test_RevertWhen_NonOwnerConfirms() public {
        uint256 txIndex = _submitBasicTx(receiver, 0.1 ether, "");

        vm.prank(nonOwner);
        vm.expectRevert("Not owner");
        wallet.confirmTransaction(txIndex);
    }

    function test_RevertWhen_DoubleConfirm() public {
        uint256 txIndex = _submitBasicTx(receiver, 0, "");

        vm.prank(owner1);
        wallet.confirmTransaction(txIndex);

        vm.prank(owner1);
        vm.expectRevert("Already confirmed");
        wallet.confirmTransaction(txIndex);
    }

    function test_RevertWhen_ExecuteBelowThreshold() public {
        vm.deal(address(wallet), 1 ether);
        uint256 txIndex = _submitBasicTx(receiver, 0.2 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(txIndex);

        vm.prank(owner2);
        vm.expectRevert("Insufficient confirmations");
        wallet.executeTransaction(txIndex);
    }

    function testRevokeAndReconfirmFlow() public {
        vm.deal(address(wallet), 1 ether);
        uint256 txIndex = _submitBasicTx(receiver, 0.3 ether, "");

        _confirmBy(owner1, txIndex);
        _confirmBy(owner2, txIndex);

        vm.prank(owner2);
        wallet.revokeConfirmation(txIndex);

        (, , , , uint256 confirmationCountAfterRevoke) = wallet.transactions(
            txIndex
        );
        assertEq(confirmationCountAfterRevoke, 1);

        _confirmBy(owner3, txIndex);

        vm.prank(owner1);
        wallet.executeTransaction(txIndex);

        (, , , bool executed, uint256 finalCount) = wallet.transactions(txIndex);
        assertTrue(executed);
        assertEq(finalCount, 2);
    }

    function test_RevertWhen_RevokeWithoutConfirmation() public {
        uint256 txIndex = _submitBasicTx(receiver, 0, "");

        vm.prank(owner1);
        vm.expectRevert("Not confirmed");
        wallet.revokeConfirmation(txIndex);
    }

    function test_RevertWhen_ExecuteTransactionTwice() public {
        vm.deal(address(wallet), 1 ether);
        uint256 txIndex = _submitBasicTx(receiver, 0.1 ether, "");

        _confirmBy(owner1, txIndex);
        _confirmBy(owner2, txIndex);

        vm.prank(owner1);
        wallet.executeTransaction(txIndex);

        vm.prank(owner2);
        vm.expectRevert("Transaction already executed");
        wallet.executeTransaction(txIndex);
    }
}
