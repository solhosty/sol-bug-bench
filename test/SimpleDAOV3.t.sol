// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleDAOV3.sol";

contract Target {
    uint256 public value;

    function setValue(uint256 newValue) external payable {
        value = newValue;
    }
}

contract SimpleDAOV3Test is Test {
    SimpleDAOV3 public dao;
    Target public target;

    address public alice;
    address public bob;
    address public carol;
    address public outsider;

    uint256 public constant ALICE_POWER = 50;
    uint256 public constant BOB_POWER = 30;
    uint256 public constant CAROL_POWER = 20;
    uint256 public constant VOTING_PERIOD = 3 days;
    uint256 public constant QUORUM = 60;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");
        outsider = makeAddr("outsider");

        address[] memory members = new address[](3);
        members[0] = alice;
        members[1] = bob;
        members[2] = carol;

        uint256[] memory votingPowers = new uint256[](3);
        votingPowers[0] = ALICE_POWER;
        votingPowers[1] = BOB_POWER;
        votingPowers[2] = CAROL_POWER;

        dao = new SimpleDAOV3(members, votingPowers, VOTING_PERIOD, QUORUM);
        target = new Target();
    }

    function testDeploymentState() public {
        assertEq(dao.votingPower(alice), ALICE_POWER);
        assertEq(dao.votingPower(bob), BOB_POWER);
        assertEq(dao.votingPower(carol), CAROL_POWER);
        assertEq(dao.totalVotingPower(), 100);
        assertEq(dao.votingPeriod(), VOTING_PERIOD);
        assertEq(dao.quorum(), QUORUM);
        assertEq(dao.getProposalCount(), 0);
    }

    function testPropose() public {
        vm.prank(alice);
        uint256 proposalId = dao.propose(
            address(target),
            0,
            abi.encodeCall(Target.setValue, (10))
        );

        assertEq(proposalId, 0);
        assertEq(dao.getProposalCount(), 1);
    }

    function testVote() public {
        uint256 proposalId = _createProposal();

        vm.prank(alice);
        dao.vote(proposalId, true);

        assertTrue(dao.hasVoted(proposalId, alice));
    }

    function testExecuteWhenQuorumMet() public {
        vm.deal(address(dao), 1 ether);
        uint256 proposalId = _createProposal();

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.prank(bob);
        dao.vote(proposalId, true);

        skip(VOTING_PERIOD + 1);

        dao.execute(proposalId);

        assertEq(target.value(), 42);
    }

    function test_RevertWhen_QuorumNotMet() public {
        uint256 proposalId = _createProposal();

        vm.prank(alice);
        dao.vote(proposalId, true);

        skip(VOTING_PERIOD + 1);

        vm.expectRevert("Quorum not met");
        dao.execute(proposalId);
    }

    function test_RevertWhen_DoubleVote() public {
        uint256 proposalId = _createProposal();

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.prank(alice);
        vm.expectRevert("Already voted");
        dao.vote(proposalId, true);
    }

    function test_RevertWhen_NonMember() public {
        vm.prank(outsider);
        vm.expectRevert("Not member");
        dao.propose(address(target), 0, abi.encodeCall(Target.setValue, (11)));
    }

    function testCancelByProposer() public {
        uint256 proposalId = _createProposal();

        vm.prank(alice);
        dao.cancel(proposalId);

        skip(VOTING_PERIOD + 1);

        vm.expectRevert("Proposal cancelled");
        dao.execute(proposalId);
    }

    function test_RevertWhen_ExecuteBeforeDeadline() public {
        uint256 proposalId = _createProposal();

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.prank(bob);
        dao.vote(proposalId, true);

        vm.expectRevert("Voting not ended");
        dao.execute(proposalId);
    }

    function test_RevertWhen_YesVotesNotGreaterThanNoVotes() public {
        address[] memory members = new address[](3);
        members[0] = alice;
        members[1] = bob;
        members[2] = carol;

        uint256[] memory votingPowers = new uint256[](3);
        votingPowers[0] = ALICE_POWER;
        votingPowers[1] = BOB_POWER;
        votingPowers[2] = CAROL_POWER;

        SimpleDAOV3 tieDao = new SimpleDAOV3(members, votingPowers, VOTING_PERIOD, 40);
        vm.deal(address(tieDao), 1 ether);

        vm.prank(alice);
        uint256 proposalId = tieDao.propose(
            address(target),
            0,
            abi.encodeCall(Target.setValue, (100))
        );

        vm.prank(alice);
        tieDao.vote(proposalId, true);

        vm.prank(bob);
        tieDao.vote(proposalId, false);

        vm.prank(carol);
        tieDao.vote(proposalId, false);

        skip(VOTING_PERIOD + 1);

        vm.expectRevert("Proposal rejected");
        tieDao.execute(proposalId);
    }

    function testReceiveEth() public {
        vm.deal(alice, 5 ether);

        vm.prank(alice);
        (bool success,) = address(dao).call{value: 1 ether}("");

        assertTrue(success);
        assertEq(address(dao).balance, 1 ether);
    }

    function _createProposal() internal returns (uint256 proposalId) {
        vm.prank(alice);
        proposalId = dao.propose(
            address(target),
            0,
            abi.encodeCall(Target.setValue, (42))
        );
    }
}
