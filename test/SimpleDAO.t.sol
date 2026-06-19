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

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");

        address[] memory members = new address[](3);
        members[0] = alice;
        members[1] = bob;
        members[2] = carol;

        uint256[] memory powers = new uint256[](3);
        powers[0] = 50;
        powers[1] = 30;
        powers[2] = 20;

        dao = new SimpleDAO(members, powers, 3 days, 60);
        target = new Target();

        vm.deal(address(this), 20 ether);
        (bool ok,) = address(dao).call{value: 10 ether}("");
        require(ok, "funding failed");
    }

    function testDeployment() public view {
        assertEq(dao.votingPower(alice), 50);
        assertEq(dao.votingPower(bob), 30);
        assertEq(dao.votingPower(carol), 20);
        assertEq(dao.votingPeriod(), 3 days);
        assertEq(dao.quorum(), 60);
    }

    function testProposeAndVotePasses() public {
        bytes memory callData = abi.encodeWithSelector(Target.setX.selector, 42);

        vm.prank(alice);
        uint256 proposalId = dao.propose("Set target x", address(target), callData, 0);

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.prank(bob);
        dao.vote(proposalId, true);

        vm.warp(block.timestamp + 3 days + 1);
        dao.execute(proposalId);

        assertEq(target.x(), 42);
    }

    function testExecuteRevertsBeforeDeadline() public {
        bytes memory callData = abi.encodeWithSelector(Target.setX.selector, 1);

        vm.prank(alice);
        uint256 proposalId = dao.propose("Set x", address(target), callData, 0);

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.expectRevert("Voting not ended");
        dao.execute(proposalId);
    }

    function testExecuteRevertsOnQuorumFail() public {
        bytes memory callData = abi.encodeWithSelector(Target.setX.selector, 7);

        vm.prank(carol);
        uint256 proposalId = dao.propose("Set x", address(target), callData, 0);

        vm.prank(carol);
        dao.vote(proposalId, true);

        vm.warp(block.timestamp + 3 days + 1);
        vm.expectRevert("Quorum not reached");
        dao.execute(proposalId);
    }

    function testVoteRevertsNonMember() public {
        bytes memory callData = abi.encodeWithSelector(Target.setX.selector, 9);

        vm.prank(alice);
        uint256 proposalId = dao.propose("Set x", address(target), callData, 0);

        address dave = makeAddr("dave");
        vm.prank(dave);
        vm.expectRevert("Not a member");
        dao.vote(proposalId, true);
    }

    function testDoubleVoteReverts() public {
        bytes memory callData = abi.encodeWithSelector(Target.setX.selector, 10);

        vm.prank(alice);
        uint256 proposalId = dao.propose("Set x", address(target), callData, 0);

        vm.prank(alice);
        dao.vote(proposalId, true);

        vm.prank(alice);
        vm.expectRevert("Already voted");
        dao.vote(proposalId, true);
    }

    function testCancelByProposer() public {
        bytes memory callData = abi.encodeWithSelector(Target.setX.selector, 11);

        vm.prank(alice);
        uint256 proposalId = dao.propose("Set x", address(target), callData, 0);

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
        (bool ok,) = address(dao).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(dao).balance, beforeBalance + 1 ether);
    }
}
