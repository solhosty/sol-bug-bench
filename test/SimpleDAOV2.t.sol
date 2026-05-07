// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleDAOV2.sol";

contract Target {
    uint256 public number;

    function setNumber(uint256 newNumber) external {
        number = newNumber;
    }
}

contract SimpleDAOV2Test is Test {
    SimpleDAOV2 public dao;
    Target public target;

    address public alice;
    address public bob;
    address public carol;
    address public dave;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");
        dave = makeAddr("dave");

        address[] memory members = new address[](3);
        members[0] = alice;
        members[1] = bob;
        members[2] = carol;

        uint256[] memory powers = new uint256[](3);
        powers[0] = 50;
        powers[1] = 30;
        powers[2] = 20;

        dao = new SimpleDAOV2(members, powers, 3 days, 60);
        target = new Target();

        vm.deal(address(dao), 10 ether);
        vm.deal(alice, 10 ether);
    }

    function testDeploymentState() public {
        assertEq(dao.votingPower(alice), 50);
        assertEq(dao.votingPower(bob), 30);
        assertEq(dao.votingPower(carol), 20);
        assertEq(dao.totalVotingPower(), 100);
        assertEq(dao.votingPeriod(), 3 days);
        assertEq(dao.quorum(), 60);
        assertEq(dao.getProposalCount(), 0);
        assertEq(address(dao).balance, 10 ether);
    }

    function testPropose() public {
        vm.prank(alice);
        uint256 proposalId = dao.propose(
            address(target),
            0,
            abi.encodeCall(Target.setNumber, (7))
        );

        assertEq(proposalId, 0);
        assertEq(dao.getProposalCount(), 1);

        SimpleDAOV2.Proposal memory proposal = dao.getProposal(proposalId);
        assertEq(proposal.target, address(target));
        assertEq(proposal.value, 0);
        assertEq(proposal.deadline, block.timestamp + 3 days);
        assertEq(proposal.proposer, alice);
    }

    function testExecuteWhenQuorumMet() public {
        vm.prank(alice);
        uint256 proposalId = dao.propose(
            address(target),
            0,
            abi.encodeCall(Target.setNumber, (42))
        );

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.prank(bob);
        dao.vote(proposalId, true);

        vm.prank(carol);
        dao.execute(proposalId);

        assertEq(target.number(), 42);
        SimpleDAOV2.Proposal memory proposal = dao.getProposal(proposalId);
        assertTrue(proposal.executed);
    }

    function test_RevertWhen_QuorumNotMet() public {
        vm.prank(alice);
        uint256 proposalId = dao.propose(
            address(target),
            0,
            abi.encodeCall(Target.setNumber, (42))
        );

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.prank(alice);
        vm.expectRevert("Quorum not met");
        dao.execute(proposalId);
    }

    function test_RevertWhen_DoubleVote() public {
        vm.prank(alice);
        uint256 proposalId = dao.propose(
            address(target),
            0,
            abi.encodeCall(Target.setNumber, (1))
        );

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.prank(alice);
        vm.expectRevert("Already voted");
        dao.vote(proposalId, false);
    }

    function test_RevertWhen_NonMemberActs() public {
        vm.prank(dave);
        vm.expectRevert("Not a member");
        dao.propose(address(target), 0, abi.encodeCall(Target.setNumber, (9)));
    }

    function testCancelByProposer() public {
        vm.prank(alice);
        uint256 proposalId = dao.propose(
            address(target),
            0,
            abi.encodeCall(Target.setNumber, (5))
        );

        vm.prank(alice);
        dao.cancel(proposalId);

        SimpleDAOV2.Proposal memory proposal = dao.getProposal(proposalId);
        assertTrue(proposal.cancelled);
    }

    function test_RevertWhen_ExecuteAfterDeadline() public {
        vm.prank(alice);
        uint256 proposalId = dao.propose(
            address(target),
            0,
            abi.encodeCall(Target.setNumber, (100))
        );

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.prank(bob);
        dao.vote(proposalId, true);

        skip(3 days + 1);

        vm.prank(carol);
        vm.expectRevert("Proposal expired");
        dao.execute(proposalId);
    }

    function testReceiveEth() public {
        uint256 amount = 1 ether;

        vm.prank(alice);
        (bool success,) = address(dao).call{value: amount}("");

        assertTrue(success);
        assertEq(address(dao).balance, 11 ether);
    }
}
