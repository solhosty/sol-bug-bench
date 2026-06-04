// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MultiSig.sol";

contract MultiSigTarget {
    uint256 public storedValue;

    function setValue(uint256 newValue) external {
        storedValue = newValue;
    }

    receive() external payable {}
}

contract MultiSigTest is Test {
    MultiSig public wallet;
    MultiSigTarget public target;

    address public owner1;
    address public owner2;
    address public owner3;
    address public outsider;

    function setUp() public {
        owner1 = address(this);
        owner2 = makeAddr("owner2");
        owner3 = makeAddr("owner3");
        outsider = makeAddr("outsider");

        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        wallet = new MultiSig(owners, 2);
        target = new MultiSigTarget();

        vm.deal(owner1, 10 ether);
        vm.prank(owner1);
        (bool success,) = address(wallet).call{value: 5 ether}("");
        require(success, "funding failed");
    }

    function testSubmitConfirmAndExecuteTransaction() public {
        wallet.submitTransaction(address(target), 1 ether, "");

        vm.prank(owner2);
        wallet.confirmTransaction(0);
        wallet.confirmTransaction(0);

        wallet.executeTransaction(0);

        (, , , bool executed, uint256 numConfirmations) = wallet.transactions(0);

        assertEq(address(target).balance, 1 ether);
        assertEq(executed, true);
        assertEq(numConfirmations, 2);
    }

    function test_RevertWhen_NonOwnerSubmitsTransaction() public {
        vm.prank(outsider);
        vm.expectRevert("Not owner");
        wallet.submitTransaction(address(target), 1 ether, "");
    }

    function test_RevertWhen_DuplicateConfirmation() public {
        wallet.submitTransaction(address(target), 0, abi.encodeWithSelector(MultiSigTarget.setValue.selector, 7));

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        vm.expectRevert("Tx already confirmed");
        wallet.confirmTransaction(0);
    }

    function testExecuteWithoutRequiredConfirmationsIssue() public {
        wallet.submitTransaction(address(target), 2 ether, "");

        vm.prank(outsider);
        wallet.executeTransaction(0);

        (, , , bool executed, uint256 numConfirmations) = wallet.transactions(0);

        assertEq(address(target).balance, 2 ether);
        assertEq(executed, true);
        assertEq(numConfirmations, 0);
    }
}
