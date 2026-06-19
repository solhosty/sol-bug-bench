// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleDAO.sol";

contract Target {
    uint256 public counter;
    uint256 public received;

    function increment() external payable {
        counter += 1;
        received += msg.value;
    }

    receive() external payable {
        received += msg.value;
    }
}

contract SimpleDAOTest is Test {
    SimpleDAO public dao;
    Target public target;

    address public alice;
    address public bob;
    address public carol;
    address public dave;

    uint256 public constant ALICE_POWER = 50;
    uint256 public constant BOB_POWER = 30;
    uint256 public constant CAROL_POWER = 20;
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
        powers[0] = ALICE_POWER;
        powers[1] = BOB_POWER;
        powers[2] = CAROL_POWER;

        dao = new SimpleDAO(members, powers, VOTING_PERIOD, QUORUM);
        target = new Target();

        vm.deal(address(dao), 10 ether);
    }

    function testDeployment() public {
        assertEq(dao.votingPower(alice), ALICE_POWER);
        assertEq(dao.votingPower(bob), BOB_POWER);
        assertEq(dao.votingPower(carol), CAROL_POWER);
        assertEq(dao.totalVotingPower(), ALICE_POWER + BOB_POWER + CAROL_POWER);
        assertEq(dao.votingPeriod(), VOTING_PERIOD);
        assertEq(dao.quorum(), QUORUM);
        assertEq(dao.getProposalCount(), 0);
        assertEq(address(dao).balance, 10 ether);
    }

    function testPropose() public {
        bytes memory data = abi.encodeWithSelector(Target.increment.selector);

        vm.prank(alice);
        uint256 proposalId = dao.propose(address(target), 1 ether, data);

        assertEq(proposalId, 0);
        assertEq(dao.getProposalCount(), 1);

        (
            address proposalTarget,
            uint256 proposalValue,
            bytes memory proposalData,
            uint256 deadline,
            uint256 yesVotes,
            uint256 noVotes,
            bool executed,
            bool cancelled,
            address proposer
        ) = dao.proposals(0);

        assertEq(proposalTarget, address(target));
        assertEq(proposalValue, 1 ether);
        assertEq(keccak256(proposalData), keccak256(data));
        assertEq(deadline, block.timestamp + VOTING_PERIOD);
        assertEq(yesVotes, 0);
        assertEq(noVotes, 0);
        assertFalse(executed);
        assertFalse(cancelled);
        assertEq(proposer, alice);
    }

    function testExecuteOnQuorum() public {
        bytes memory data = abi.encodeWithSelector(Target.increment.selector);

        vm.prank(alice);
        uint256 proposalId = dao.propose(address(target), 1 ether, data);

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.prank(bob);
        dao.vote(proposalId, true);

        dao.execute(proposalId);

        (, , , , , , bool executed, , ) = dao.proposals(proposalId);
        assertTrue(executed);
        assertEq(target.counter(), 1);
        assertEq(target.received(), 1 ether);
        assertEq(address(dao).balance, 9 ether);
    }

    function test_RevertWhen_QuorumNotMet() public {
        bytes memory data = abi.encodeWithSelector(Target.increment.selector);

        vm.prank(alice);
        uint256 proposalId = dao.propose(address(target), 0, data);

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.expectRevert("Quorum not met");
        dao.execute(proposalId);
    }

    function test_RevertWhen_DoubleVote() public {
        bytes memory data = abi.encodeWithSelector(Target.increment.selector);

        vm.prank(alice);
        uint256 proposalId = dao.propose(address(target), 0, data);

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.prank(alice);
        vm.expectRevert("Already voted");
        dao.vote(proposalId, false);
    }

    function test_RevertWhen_NonMemberPropose() public {
        bytes memory data = abi.encodeWithSelector(Target.increment.selector);

        vm.prank(dave);
        vm.expectRevert("Not a member");
        dao.propose(address(target), 0, data);
    }

    function testCancelByProposer() public {
        bytes memory data = abi.encodeWithSelector(Target.increment.selector);

        vm.prank(alice);
        uint256 proposalId = dao.propose(address(target), 0, data);

        vm.prank(alice);
        dao.cancel(proposalId);

        (, , , , , , , bool cancelled, ) = dao.proposals(proposalId);
        assertTrue(cancelled);

        vm.expectRevert("Proposal cancelled");
        dao.execute(proposalId);
    }

    function test_RevertWhen_ExecuteAfterDeadline() public {
        bytes memory data = abi.encodeWithSelector(Target.increment.selector);

        vm.prank(alice);
        uint256 proposalId = dao.propose(address(target), 0, data);

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.prank(bob);
        dao.vote(proposalId, true);

        skip(VOTING_PERIOD + 1);

        vm.expectRevert("Execution window closed");
        dao.execute(proposalId);
    }

    function testEthReceive() public {
        vm.deal(alice, 1 ether);

        vm.prank(alice);
        (bool success, ) = address(dao).call{value: 1 ether}("");

        assertTrue(success);
        assertEq(address(dao).balance, 11 ether);
    }
}
