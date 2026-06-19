// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleDAO.sol";

contract Target {
    uint256 public x;

    function setX(uint256 _x) external {
        x = _x;
    }
}

contract SimpleDAOTest is Test {
    SimpleDAO internal dao;
    Target internal target;

    address internal alice;
    address internal bob;
    address internal carol;

    uint256 internal constant ALICE_POWER = 50;
    uint256 internal constant BOB_POWER = 30;
    uint256 internal constant CAROL_POWER = 20;
    uint256 internal constant VOTING_PERIOD = 3 days;
    uint256 internal constant QUORUM = 60;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");

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
        assertEq(dao.votingPeriod(), VOTING_PERIOD);
        assertEq(dao.quorum(), QUORUM);
        assertEq(dao.getProposalCount(), 0);
    }

    function testProposeAndVotePasses() public {
        bytes memory data = abi.encodeWithSelector(Target.setX.selector, 42);

        vm.prank(alice);
        uint256 proposalId = dao.propose("Set x", address(target), data, 0);

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.prank(bob);
        dao.vote(proposalId, true);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        dao.execute(proposalId);

        assertEq(target.x(), 42);
    }

    function testExecuteRevertsBeforeDeadline() public {
        bytes memory data = abi.encodeWithSelector(Target.setX.selector, 7);

        vm.prank(alice);
        uint256 proposalId = dao.propose("Set x", address(target), data, 0);

        vm.expectRevert("Voting still active");
        dao.execute(proposalId);
    }

    function testExecuteRevertsOnQuorumFail() public {
        bytes memory data = abi.encodeWithSelector(Target.setX.selector, 99);

        vm.prank(carol);
        uint256 proposalId = dao.propose("Set x", address(target), data, 0);

        vm.prank(carol);
        dao.vote(proposalId, true);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);

        vm.expectRevert("Quorum not reached");
        dao.execute(proposalId);
    }

    function testVoteRevertsNonMember() public {
        address nonMember = makeAddr("nonMember");
        bytes memory data = abi.encodeWithSelector(Target.setX.selector, 1);

        vm.prank(alice);
        uint256 proposalId = dao.propose("Set x", address(target), data, 0);

        vm.prank(nonMember);
        vm.expectRevert("Not a member");
        dao.vote(proposalId, true);
    }

    function testDoubleVoteReverts() public {
        bytes memory data = abi.encodeWithSelector(Target.setX.selector, 11);

        vm.prank(alice);
        uint256 proposalId = dao.propose("Set x", address(target), data, 0);

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.prank(alice);
        vm.expectRevert("Already voted");
        dao.vote(proposalId, false);
    }

    function testCancelByProposer() public {
        bytes memory data = abi.encodeWithSelector(Target.setX.selector, 55);

        vm.prank(alice);
        uint256 proposalId = dao.propose("Set x", address(target), data, 0);

        vm.prank(bob);
        vm.expectRevert("Not proposer");
        dao.cancel(proposalId);

        vm.prank(alice);
        dao.cancel(proposalId);

        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            bool canceled
        ) = dao.proposals(proposalId);
        assertTrue(canceled);
    }

    function testReceiveEth() public {
        uint256 beforeBalance = address(dao).balance;

        vm.deal(address(this), 1 ether);
        (bool ok,) = payable(address(dao)).call{value: 1 ether}("");

        assertTrue(ok);
        assertEq(address(dao).balance, beforeBalance + 1 ether);
    }
}
