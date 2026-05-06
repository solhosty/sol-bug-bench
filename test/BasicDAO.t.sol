// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/BasicDAO.sol";

contract BasicDAOTest is Test {
    BasicDAO public dao;
    address public member1;
    address public member2;
    address public nonMember;

    function setUp() public {
        dao = new BasicDAO();

        member1 = makeAddr("member1");
        member2 = makeAddr("member2");
        nonMember = makeAddr("nonMember");

        dao.addMember(member1);
        dao.addMember(member2);
    }

    function test_OwnerCanAddAndRemoveMembers() public {
        address newMember = makeAddr("newMember");

        dao.addMember(newMember);
        assertTrue(dao.isMember(newMember));

        dao.removeMember(newMember);
        assertFalse(dao.isMember(newMember));
    }

    function test_OnlyMemberCanCreateProposal() public {
        vm.prank(nonMember);
        vm.expectRevert("Only member");
        dao.createProposal("Add feature", 1 days);
    }

    function test_VoteAndTallyYes() public {
        vm.prank(member1);
        uint256 proposalId = dao.createProposal("Treasury motion", 1 days);

        vm.prank(member1);
        dao.vote(proposalId, true);

        vm.prank(member2);
        dao.vote(proposalId, true);

        vm.warp(block.timestamp + 1 days + 1);
        dao.execute(proposalId);

        (, , , , , bool executed) = dao.proposals(proposalId);
        assertTrue(executed);
    }

    function test_CannotVoteAfterDeadline() public {
        vm.prank(member1);
        uint256 proposalId = dao.createProposal("Expired vote", 1 days);

        vm.warp(block.timestamp + 1 days + 1);

        vm.prank(member1);
        vm.expectRevert("Voting ended");
        dao.vote(proposalId, true);
    }

    function test_ExecuteMarksExecutedAndCannotReexecute() public {
        vm.prank(member1);
        uint256 proposalId = dao.createProposal("One-time execute", 1 days);

        vm.prank(member1);
        dao.vote(proposalId, true);

        vm.warp(block.timestamp + 1 days + 1);

        dao.execute(proposalId);

        (, , , , , bool executed) = dao.proposals(proposalId);
        assertTrue(executed);

        vm.expectRevert("Already executed");
        dao.execute(proposalId);
    }
}
