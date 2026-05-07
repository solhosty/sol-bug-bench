// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleDAOV8.sol";

contract Target {
    uint256 public counter;
    uint256 public lastValue;

    function increment() external payable {
        counter += 1;
        lastValue = msg.value;
    }
}

contract SimpleDAOV8Test is Test {
    SimpleDAOV8 public dao;
    Target public target;

    address public member1;
    address public member2;
    address public member3;
    address public nonMember;

    uint256 public constant VOTING_PERIOD = 3 days;
    uint256 public constant QUORUM = 60;

    function setUp() public {
        member1 = makeAddr("member1");
        member2 = makeAddr("member2");
        member3 = makeAddr("member3");
        nonMember = makeAddr("nonMember");

        address[] memory members = new address[](3);
        members[0] = member1;
        members[1] = member2;
        members[2] = member3;

        uint256[] memory powers = new uint256[](3);
        powers[0] = 50;
        powers[1] = 30;
        powers[2] = 20;

        dao = new SimpleDAOV8(members, powers, VOTING_PERIOD, QUORUM);
        target = new Target();

        vm.deal(address(this), 100 ether);
        (bool success,) = address(dao).call{value: 10 ether}("");
        require(success, "funding failed");
    }

    function testDeploymentState() public view {
        assertEq(dao.votingPeriod(), VOTING_PERIOD);
        assertEq(dao.quorum(), QUORUM);
        assertEq(dao.totalVotingPower(), 100);
        assertEq(dao.votingPower(member1), 50);
        assertEq(dao.votingPower(member2), 30);
        assertEq(dao.votingPower(member3), 20);
        assertEq(dao.getProposalCount(), 0);
        assertEq(address(dao).balance, 10 ether);
    }

    function testPropose() public {
        bytes memory data = abi.encodeWithSignature("increment()");

        vm.prank(member1);
        uint256 proposalId = dao.propose(address(target), 1 ether, data);

        assertEq(proposalId, 0);
        assertEq(dao.getProposalCount(), 1);
    }

    function testVoteAndExecuteOnQuorum() public {
        uint256 proposalId = _createIncrementProposal(1 ether);

        vm.prank(member1);
        dao.vote(proposalId, true);

        vm.prank(member2);
        dao.vote(proposalId, true);

        skip(VOTING_PERIOD + 1);

        vm.prank(member3);
        dao.execute(proposalId);

        assertEq(target.counter(), 1);
        assertEq(target.lastValue(), 1 ether);
        assertEq(address(dao).balance, 9 ether);
    }

    function test_RevertWhen_QuorumNotMet() public {
        uint256 proposalId = _createIncrementProposal(0);

        vm.prank(member1);
        dao.vote(proposalId, true);

        skip(VOTING_PERIOD + 1);

        vm.prank(member2);
        vm.expectRevert("Quorum not met");
        dao.execute(proposalId);
    }

    function test_RevertWhen_DoubleVote() public {
        uint256 proposalId = _createIncrementProposal(0);

        vm.startPrank(member1);
        dao.vote(proposalId, true);
        vm.expectRevert("Already voted");
        dao.vote(proposalId, false);
        vm.stopPrank();
    }

    function test_RevertWhen_NonMemberCallsMemberFunction() public {
        bytes memory data = abi.encodeWithSignature("increment()");

        vm.prank(nonMember);
        vm.expectRevert("Not a member");
        dao.propose(address(target), 0, data);
    }

    function testCancelByProposer() public {
        uint256 proposalId = _createIncrementProposal(0);

        vm.prank(member1);
        dao.cancel(proposalId);

        vm.prank(member2);
        vm.expectRevert("Proposal cancelled");
        dao.vote(proposalId, true);
    }

    function test_RevertWhen_CancelAfterVoteStarted() public {
        uint256 proposalId = _createIncrementProposal(0);

        vm.prank(member2);
        dao.vote(proposalId, true);

        vm.prank(member1);
        vm.expectRevert("Voting started");
        dao.cancel(proposalId);
    }

    function test_RevertWhen_CancelAfterDeadline() public {
        uint256 proposalId = _createIncrementProposal(0);

        skip(VOTING_PERIOD + 1);

        vm.prank(member1);
        vm.expectRevert("Voting ended");
        dao.cancel(proposalId);
    }

    function test_RevertWhen_ExecuteBeforeDeadline() public {
        uint256 proposalId = _createIncrementProposal(0);

        vm.prank(member1);
        dao.vote(proposalId, true);

        vm.prank(member2);
        dao.vote(proposalId, true);

        vm.prank(member3);
        vm.expectRevert("Voting not ended");
        dao.execute(proposalId);
    }

    function testReceiveEther() public {
        vm.deal(member1, 2 ether);

        vm.prank(member1);
        (bool success,) = address(dao).call{value: 2 ether}("");
        assertTrue(success);
        assertEq(address(dao).balance, 12 ether);
    }

    function _createIncrementProposal(uint256 value) internal returns (uint256) {
        bytes memory data = abi.encodeWithSignature("increment()");

        vm.prank(member1);
        return dao.propose(address(target), value, data);
    }
}
