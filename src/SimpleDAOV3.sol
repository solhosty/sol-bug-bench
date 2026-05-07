// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleDAOV3 {
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

    mapping(address => uint256) public votingPower;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    uint256 public immutable votingPeriod;
    uint256 public immutable quorum;
    uint256 public totalVotingPower;

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
    event ProposalExecuted(uint256 indexed proposalId, address indexed executor);
    event ProposalCancelled(uint256 indexed proposalId, address indexed proposer);

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
        require(members.length > 0, "Empty members");
        require(members.length == votingPowers.length, "Length mismatch");
        require(votingPeriod_ > 0, "Invalid voting period");
        require(quorum_ > 0, "Invalid quorum");

        votingPeriod = votingPeriod_;
        quorum = quorum_;

        for (uint256 i = 0; i < members.length; i++) {
            address member = members[i];
            uint256 power = votingPowers[i];

            require(member != address(0), "Invalid member");
            require(power > 0, "Zero voting power");
            require(votingPower[member] == 0, "Duplicate member");

            votingPower[member] = power;
            totalVotingPower += power;
        }
    }

    receive() external payable {}

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

        require(block.timestamp <= proposal.deadline, "Voting ended");
        require(!proposal.executed, "Already executed");
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

    function execute(uint256 proposalId) external {
        require(proposalId < proposals.length, "Invalid proposal");

        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp > proposal.deadline, "Voting not ended");
        require(!proposal.executed, "Already executed");
        require(!proposal.cancelled, "Proposal cancelled");
        require(proposal.yesVotes >= quorum, "Quorum not met");
        require(proposal.yesVotes > proposal.noVotes, "Proposal rejected");
        require(address(this).balance >= proposal.value, "Insufficient ETH");

        proposal.executed = true;

        (bool success,) = proposal.target.call{value: proposal.value}(proposal.data);
        require(success, "Execution failed");

        emit ProposalExecuted(proposalId, msg.sender);
    }

    function cancel(uint256 proposalId) external {
        require(proposalId < proposals.length, "Invalid proposal");

        Proposal storage proposal = proposals[proposalId];

        require(msg.sender == proposal.proposer, "Not proposer");
        require(!proposal.executed, "Already executed");
        require(!proposal.cancelled, "Already cancelled");
        require(
            block.timestamp <= proposal.deadline
                || proposal.yesVotes < quorum
                || proposal.yesVotes <= proposal.noVotes,
            "Proposal passed"
        );

        proposal.cancelled = true;

        emit ProposalCancelled(proposalId, msg.sender);
    }

    function getProposalCount() external view returns (uint256) {
        return proposals.length;
    }

}
