// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleDAO.sol";

contract Target {
    uint256 public count;
    uint256 public lastValue;

    function increment() external payable {
        count += 1;
        lastValue = msg.value;
    }
}

contract SimpleDAOTest is Test {
    SimpleDAO public dao;
    Target public target;

    address public alice;
    address public bob;
    address public carol;
    address public dave;

    uint256 public constant VOTING_PERIOD = 3 days;
    uint256 public constant QUORUM = 60;

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

        dao = new SimpleDAO(members, powers, VOTING_PERIOD, QUORUM);
        target = new Target();

        vm.deal(address(this), 20 ether);
        payable(address(dao)).transfer(10 ether);
    }

    function testDeploymentState() public view {
        assertEq(dao.votingPower(alice), 50);
        assertEq(dao.votingPower(bob), 30);
        assertEq(dao.votingPower(carol), 20);
        assertEq(dao.votingPeriod(), VOTING_PERIOD);
        assertEq(dao.quorum(), QUORUM);
        assertEq(dao.getProposalCount(), 0);
        assertEq(address(dao).balance, 10 ether);
    }

    function testProposeCreatesProposal() public {
        bytes memory callData = abi.encodeWithSignature("increment()");

        vm.prank(alice);
        uint256 proposalId = dao.propose(address(target), 1 ether, callData);

        assertEq(proposalId, 0);
        assertEq(dao.getProposalCount(), 1);

        SimpleDAO.Proposal memory proposal = dao.getProposal(proposalId);
        assertEq(proposal.target, address(target));
        assertEq(proposal.value, 1 ether);
        assertEq(proposal.proposer, alice);
        assertEq(proposal.deadline, block.timestamp + VOTING_PERIOD);
    }

    function testVoteTracksYesAndNoVotes() public {
        uint256 proposalId = _createIncrementProposal(alice, 0);

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.prank(carol);
        dao.vote(proposalId, false);

        SimpleDAO.Proposal memory proposal = dao.getProposal(proposalId);
        assertEq(proposal.yesVotes, 50);
        assertEq(proposal.noVotes, 20);
        assertTrue(dao.hasVoted(proposalId, alice));
        assertTrue(dao.hasVoted(proposalId, carol));
    }

    function testExecuteWhenQuorumMet() public {
        uint256 proposalId = _createIncrementProposal(alice, 1 ether);

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.prank(bob);
        dao.vote(proposalId, true);

        vm.prank(carol);
        dao.execute(proposalId);

        assertEq(target.count(), 1);
        assertEq(target.lastValue(), 1 ether);

        SimpleDAO.Proposal memory proposal = dao.getProposal(proposalId);
        assertTrue(proposal.executed);
    }

    function testExecuteRevertsWhenQuorumNotMet() public {
        uint256 proposalId = _createIncrementProposal(alice, 0);

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.prank(bob);
        vm.expectRevert("Quorum not met");
        dao.execute(proposalId);
    }

    function testDoubleVoteReverts() public {
        uint256 proposalId = _createIncrementProposal(alice, 0);

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.prank(alice);
        vm.expectRevert("Already voted");
        dao.vote(proposalId, false);
    }

    function testNonMemberReverts() public {
        bytes memory callData = abi.encodeWithSignature("increment()");

        vm.prank(dave);
        vm.expectRevert("Not member");
        dao.propose(address(target), 0, callData);

        uint256 proposalId = _createIncrementProposal(alice, 0);

        vm.prank(dave);
        vm.expectRevert("Not member");
        dao.vote(proposalId, true);
    }

    function testCancelByProposer() public {
        uint256 proposalId = _createIncrementProposal(alice, 0);

        vm.prank(alice);
        dao.cancel(proposalId);

        SimpleDAO.Proposal memory proposal = dao.getProposal(proposalId);
        assertTrue(proposal.cancelled);
    }

    function testExecuteAfterDeadlineReverts() public {
        uint256 proposalId = _createIncrementProposal(alice, 0);

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.prank(bob);
        dao.vote(proposalId, true);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        vm.prank(alice);
        vm.expectRevert("Voting period ended");
        dao.execute(proposalId);
    }

    function testReceiveEth() public {
        uint256 initialBalance = address(dao).balance;

        vm.deal(bob, 2 ether);
        vm.prank(bob);
        payable(address(dao)).transfer(1 ether);

        assertEq(address(dao).balance, initialBalance + 1 ether);
    }

    function _createIncrementProposal(
        address proposer,
        uint256 value
    ) internal returns (uint256 proposalId) {
        bytes memory callData = abi.encodeWithSignature("increment()");

        vm.prank(proposer);
        proposalId = dao.propose(address(target), value, callData);
    }
}
