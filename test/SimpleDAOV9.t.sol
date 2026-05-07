// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleDAOV9.sol";

contract TargetV9 {
    uint256 public counter;
    uint256 public lastValue;

    function increment() external payable {
        counter += 1;
        lastValue = msg.value;
    }
}

contract SimpleDAOV9Test is Test {
    SimpleDAOV9 public dao;
    TargetV9 public target;

    address public member1;
    address public member2;
    address public member3;
    address public nonMember;

    uint256 public constant VOTING_PERIOD = 3 days;

    function setUp() public {
        member1 = makeAddr("member1");
        member2 = makeAddr("member2");
        member3 = makeAddr("member3");
        nonMember = makeAddr("nonMember");

        address[] memory members = new address[](3);
        members[0] = member1;
        members[1] = member2;
        members[2] = member3;

        dao = new SimpleDAOV9(members, VOTING_PERIOD);
        target = new TargetV9();

        vm.deal(address(dao), 10 ether);
    }

    function testPropose() public {
        bytes memory data = abi.encodeWithSignature("increment()");

        vm.prank(member1);
        uint256 proposalId = dao.propose(address(target), 1 ether, data, "increment target");

        (
            uint256 id,
            address proposer,
            address proposalTarget,
            uint256 value,
            ,
            string memory description,
            uint256 yesVotes,
            uint256 noVotes,
            uint256 deadline,
            bool executed
        ) = dao.proposals(proposalId);

        assertEq(id, proposalId);
        assertEq(proposer, member1);
        assertEq(proposalTarget, address(target));
        assertEq(value, 1 ether);
        assertEq(description, "increment target");
        assertEq(yesVotes, 0);
        assertEq(noVotes, 0);
        assertEq(deadline, block.timestamp + VOTING_PERIOD);
        assertEq(executed, false);
    }

    function testVote() public {
        bytes memory data = abi.encodeWithSignature("increment()");

        vm.prank(member1);
        uint256 proposalId = dao.propose(address(target), 0, data, "vote test");

        vm.prank(member2);
        dao.vote(proposalId, true);

        vm.prank(member3);
        dao.vote(proposalId, false);

        (, , , , , , uint256 yesVotes, uint256 noVotes, ,) = dao.proposals(proposalId);
        assertEq(yesVotes, 1);
        assertEq(noVotes, 1);
        assertTrue(dao.hasVoted(proposalId, member2));
        assertTrue(dao.hasVoted(proposalId, member3));
    }

    function testExecute() public {
        bytes memory data = abi.encodeWithSignature("increment()");

        vm.prank(member1);
        uint256 proposalId = dao.propose(address(target), 1 ether, data, "execute test");

        vm.prank(member1);
        dao.vote(proposalId, true);
        vm.prank(member2);
        dao.vote(proposalId, true);
        vm.prank(member3);
        dao.vote(proposalId, false);

        skip(VOTING_PERIOD);

        dao.execute(proposalId);

        assertEq(target.counter(), 1);
        assertEq(target.lastValue(), 1 ether);
        (, , , , , , , , , bool executed) = dao.proposals(proposalId);
        assertTrue(executed);
    }

    function test_RevertWhen_NonMemberProposes() public {
        bytes memory data = abi.encodeWithSignature("increment()");

        vm.prank(nonMember);
        vm.expectRevert("Not a member");
        dao.propose(address(target), 0, data, "non-member propose");
    }

    function test_RevertWhen_NonMemberVotes() public {
        bytes memory data = abi.encodeWithSignature("increment()");

        vm.prank(member1);
        uint256 proposalId = dao.propose(address(target), 0, data, "non-member vote");

        vm.prank(nonMember);
        vm.expectRevert("Not a member");
        dao.vote(proposalId, true);
    }

    function test_RevertWhen_DoubleVote() public {
        bytes memory data = abi.encodeWithSignature("increment()");

        vm.prank(member1);
        uint256 proposalId = dao.propose(address(target), 0, data, "double vote");

        vm.prank(member2);
        dao.vote(proposalId, true);

        vm.prank(member2);
        vm.expectRevert("Already voted");
        dao.vote(proposalId, false);
    }

    function test_RevertWhen_VotingAfterDeadline() public {
        bytes memory data = abi.encodeWithSignature("increment()");

        vm.prank(member1);
        uint256 proposalId = dao.propose(address(target), 0, data, "vote after deadline");

        skip(VOTING_PERIOD);

        vm.prank(member2);
        vm.expectRevert("Voting has ended");
        dao.vote(proposalId, true);
    }

    function test_RevertWhen_ExecuteBeforeDeadline() public {
        bytes memory data = abi.encodeWithSignature("increment()");

        vm.prank(member1);
        uint256 proposalId = dao.propose(address(target), 0, data, "execute before deadline");

        vm.prank(member2);
        dao.vote(proposalId, true);

        vm.expectRevert("Voting is still active");
        dao.execute(proposalId);
    }

    function test_RevertWhen_ExecuteTie() public {
        bytes memory data = abi.encodeWithSignature("increment()");

        vm.prank(member1);
        uint256 proposalId = dao.propose(address(target), 0, data, "execute tie");

        vm.prank(member1);
        dao.vote(proposalId, true);
        vm.prank(member2);
        dao.vote(proposalId, false);

        skip(VOTING_PERIOD);

        vm.expectRevert("Proposal not passed");
        dao.execute(proposalId);
    }

    function test_RevertWhen_ExecuteNotPassed() public {
        bytes memory data = abi.encodeWithSignature("increment()");

        vm.prank(member1);
        uint256 proposalId = dao.propose(address(target), 0, data, "execute not passed");

        vm.prank(member1);
        dao.vote(proposalId, false);
        vm.prank(member2);
        dao.vote(proposalId, false);
        vm.prank(member3);
        dao.vote(proposalId, true);

        skip(VOTING_PERIOD);

        vm.expectRevert("Proposal not passed");
        dao.execute(proposalId);
    }

    function test_RevertWhen_ExecuteWithoutQuorum() public {
        bytes memory data = abi.encodeWithSignature("increment()");

        vm.prank(member1);
        uint256 proposalId = dao.propose(address(target), 0, data, "no quorum");

        vm.prank(member1);
        dao.vote(proposalId, true);

        skip(VOTING_PERIOD);

        vm.expectRevert("Insufficient approvals");
        dao.execute(proposalId);
    }

    function test_RevertWhen_AlreadyExecuted() public {
        bytes memory data = abi.encodeWithSignature("increment()");

        vm.prank(member1);
        uint256 proposalId = dao.propose(address(target), 0, data, "already executed");

        vm.prank(member1);
        dao.vote(proposalId, true);
        vm.prank(member2);
        dao.vote(proposalId, true);

        skip(VOTING_PERIOD);

        dao.execute(proposalId);

        vm.expectRevert("Proposal already executed");
        dao.execute(proposalId);
    }
}
