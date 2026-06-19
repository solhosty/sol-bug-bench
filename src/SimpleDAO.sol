// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleDAO {
    struct Proposal {
        address target;
        uint256 value;
        bytes data;
        uint256 deadline;
        uint256 yesVotes;
        uint256 noVotes;
        bool executed;
        bool cancelled;
        address proposer;
    }

    uint256 public immutable votingPeriod;
    uint256 public immutable quorum;

    mapping(address => uint256) public votingPower;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    Proposal[] private proposals;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address indexed target,
        uint256 value,
        uint256 deadline,
        bytes data
    );
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    modifier onlyMember() {
        require(votingPower[msg.sender] > 0, "Not member");
        _;
    }

    constructor(
        address[] memory members,
        uint256[] memory votingPowers,
        uint256 votingPeriod_,
        uint256 quorum_
    ) {
        require(members.length > 0, "No members");
        require(members.length == votingPowers.length, "Length mismatch");
        require(votingPeriod_ > 0, "Voting period is zero");
        require(quorum_ > 0, "Quorum is zero");

        for (uint256 i = 0; i < members.length; i++) {
            address member = members[i];
            uint256 power = votingPowers[i];

            require(member != address(0), "Invalid member");
            require(power > 0, "Zero voting power");
            require(votingPower[member] == 0, "Duplicate member");

            votingPower[member] = power;
        }

        votingPeriod = votingPeriod_;
        quorum = quorum_;
    }

    function propose(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyMember returns (uint256 proposalId) {
        require(target != address(0), "Invalid target");

        proposalId = proposals.length;
        uint256 deadline = block.timestamp + votingPeriod;

        proposals.push(
            Proposal({
                target: target,
                value: value,
                data: data,
                deadline: deadline,
                yesVotes: 0,
                noVotes: 0,
                executed: false,
                cancelled: false,
                proposer: msg.sender
            })
        );

        emit ProposalCreated(proposalId, msg.sender, target, value, deadline, data);
    }

    function vote(uint256 proposalId, bool support) external onlyMember {
        require(proposalId < proposals.length, "Invalid proposal");

        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp <= proposal.deadline, "Voting period ended");
        require(!proposal.executed, "Proposal executed");
        require(!proposal.cancelled, "Proposal cancelled");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        hasVoted[proposalId][msg.sender] = true;

        uint256 weight = votingPower[msg.sender];
        if (support) {
            proposal.yesVotes += weight;
        } else {
            proposal.noVotes += weight;
        }

        emit Voted(proposalId, msg.sender, support, weight);
    }

    function execute(uint256 proposalId) external onlyMember {
        require(proposalId < proposals.length, "Invalid proposal");

        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp <= proposal.deadline, "Voting period ended");
        require(!proposal.executed, "Proposal executed");
        require(!proposal.cancelled, "Proposal cancelled");
        require(proposal.yesVotes >= quorum, "Quorum not met");

        proposal.executed = true;

        (bool success, ) = proposal.target.call{value: proposal.value}(proposal.data);
        require(success, "Execution failed");

        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) external {
        require(proposalId < proposals.length, "Invalid proposal");

        Proposal storage proposal = proposals[proposalId];
        require(msg.sender == proposal.proposer, "Not proposer");
        require(block.timestamp <= proposal.deadline, "Voting period ended");
        require(!proposal.executed, "Proposal executed");
        require(!proposal.cancelled, "Proposal cancelled");

        proposal.cancelled = true;

        emit ProposalCancelled(proposalId);
    }

    function getProposalCount() external view returns (uint256) {
        return proposals.length;
    }

    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        require(proposalId < proposals.length, "Invalid proposal");
        return proposals[proposalId];
    }

    receive() external payable {}
}
