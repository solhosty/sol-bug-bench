// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/GovernanceToken.sol";
import "../src/Transfer.sol";

contract TransferTest is Test {
    GovernanceToken public token;
    Transfer public transferHub;

    address public user1;
    address public user2;
    address public user3;

    function setUp() public {
        user1 = address(0x1);
        user2 = address(0x2);
        user3 = address(0x3);

        token = new GovernanceToken();
        transferHub = new Transfer(address(token));

        token.mint(user1, 1_000 * 10 ** 18);
    }

    function testSingleTransferWithoutFee() public {
        vm.startPrank(user1);
        token.approve(address(transferHub), 100 * 10 ** 18);
        transferHub.singleTransfer(user2, 100 * 10 ** 18);
        vm.stopPrank();

        assertEq(token.balanceOf(user2), 100 * 10 ** 18);
        assertEq(transferHub.accumulatedFees(), 0);
    }

    function testSingleTransferWithFee() public {
        transferHub.setFee(100);

        vm.startPrank(user1);
        token.approve(address(transferHub), 100 * 10 ** 18);
        transferHub.singleTransfer(user2, 100 * 10 ** 18);
        vm.stopPrank();

        assertEq(token.balanceOf(user2), 99 * 10 ** 18);
        assertEq(transferHub.accumulatedFees(), 1 * 10 ** 18);
    }

    function testBatchTransferValidArrays() public {
        address[] memory recipients = new address[](2);
        recipients[0] = user2;
        recipients[1] = user3;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100 * 10 ** 18;
        amounts[1] = 200 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(transferHub), 300 * 10 ** 18);
        transferHub.batchTransfer(recipients, amounts);
        vm.stopPrank();

        assertEq(token.balanceOf(user2), 100 * 10 ** 18);
        assertEq(token.balanceOf(user3), 200 * 10 ** 18);
    }

    function testBatchTransferMismatchedArrays() public {
        address[] memory recipients = new address[](2);
        recipients[0] = user2;
        recipients[1] = user3;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(transferHub), 100 * 10 ** 18);
        vm.expectRevert();
        transferHub.batchTransfer(recipients, amounts);
        vm.stopPrank();
    }

    function testPauseBlocksTransfersAndAnyoneCanUnpause() public {
        transferHub.pause();

        vm.startPrank(user1);
        token.approve(address(transferHub), 10 * 10 ** 18);
        vm.expectRevert("Transfers are paused");
        transferHub.singleTransfer(user2, 10 * 10 ** 18);
        vm.stopPrank();

        vm.prank(user2);
        transferHub.unpause();

        vm.startPrank(user1);
        transferHub.singleTransfer(user2, 10 * 10 ** 18);
        vm.stopPrank();

        assertEq(token.balanceOf(user2), 10 * 10 ** 18);
    }

    function testClaimFees() public {
        transferHub.setFee(500);

        vm.startPrank(user1);
        token.approve(address(transferHub), 100 * 10 ** 18);
        transferHub.singleTransfer(user2, 100 * 10 ** 18);
        vm.stopPrank();

        uint256 ownerBalanceBefore = token.balanceOf(address(this));
        transferHub.claimFees();

        assertEq(transferHub.accumulatedFees(), 0);
        assertEq(token.balanceOf(address(this)), ownerBalanceBefore + 5 * 10 ** 18);
    }

    function testRevertWhenZeroAmount() public {
        vm.startPrank(user1);
        token.approve(address(transferHub), 1);
        vm.expectRevert("Amount must be greater than zero");
        transferHub.singleTransfer(user2, 0);
        vm.stopPrank();
    }

    function testRevertWhenZeroRecipient() public {
        vm.startPrank(user1);
        token.approve(address(transferHub), 10 * 10 ** 18);
        vm.expectRevert("Invalid recipient");
        transferHub.singleTransfer(address(0), 10 * 10 ** 18);
        vm.stopPrank();
    }

    function testRevertWhenInsufficientAllowance() public {
        vm.startPrank(user1);
        token.approve(address(transferHub), 10 * 10 ** 18);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)",
                address(transferHub),
                10 * 10 ** 18,
                20 * 10 ** 18
            )
        );
        transferHub.singleTransfer(user2, 20 * 10 ** 18);
        vm.stopPrank();
    }
}
