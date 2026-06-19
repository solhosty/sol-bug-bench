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

    mapping(address => uint256) public votingPower;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    uint256 public immutable votingPeriod;
    uint256 public immutable quorum;
    uint256 public totalVotingPower;

    Proposal[] public proposals;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address indexed target,
        uint256 value,
        uint256 deadline
    );
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    modifier onlyMember() {
        require(votingPower[msg.sender] > 0, "Not a member");
        _;
    }

    constructor(
        address[] memory members,
        uint256[] memory votingPowers,
        uint256 _votingPeriod,
        uint256 _quorum
    ) {
        require(members.length > 0, "No members");
        require(members.length == votingPowers.length, "Length mismatch");
        require(_votingPeriod > 0, "Invalid voting period");

        for (uint256 i = 0; i < members.length; i++) {
            address member = members[i];
            uint256 power = votingPowers[i];

            require(member != address(0), "Invalid member");
            require(power > 0, "Invalid voting power");
            require(votingPower[member] == 0, "Duplicate member");

            votingPower[member] = power;
            totalVotingPower += power;
        }

        require(_quorum > 0, "Invalid quorum");
        require(_quorum <= totalVotingPower, "Quorum too high");

        votingPeriod = _votingPeriod;
        quorum = _quorum;
    }

    function propose(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyMember returns (uint256 proposalId) {
        require(target != address(0), "Invalid target");

        proposalId = proposals.length;
        proposals.push(
            Proposal({
                target: target,
                value: value,
                data: data,
                deadline: block.timestamp + votingPeriod,
                yesVotes: 0,
                noVotes: 0,
                executed: false,
                cancelled: false,
                proposer: msg.sender
            })
        );

        emit ProposalCreated(
            proposalId,
            msg.sender,
            target,
            value,
            block.timestamp + votingPeriod
        );
    }

    function vote(uint256 proposalId, bool support) external onlyMember {
        require(proposalId < proposals.length, "Invalid proposal");

        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp <= proposal.deadline, "Voting ended");
        require(!proposal.executed, "Already executed");
        require(!proposal.cancelled, "Proposal cancelled");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 weight = votingPower[msg.sender];
        hasVoted[proposalId][msg.sender] = true;

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
        require(block.timestamp <= proposal.deadline, "Execution window closed");
        require(!proposal.executed, "Already executed");
        require(!proposal.cancelled, "Proposal cancelled");
        require(proposal.yesVotes + proposal.noVotes >= quorum, "Quorum not met");
        require(proposal.yesVotes > proposal.noVotes, "Proposal not approved");

        proposal.executed = true;

        (bool success, ) = proposal.target.call{value: proposal.value}(proposal.data);
        require(success, "Execution failed");

        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) external {
        require(proposalId < proposals.length, "Invalid proposal");

        Proposal storage proposal = proposals[proposalId];
        require(msg.sender == proposal.proposer, "Not proposer");
        require(!proposal.executed, "Already executed");
        require(!proposal.cancelled, "Already cancelled");

        proposal.cancelled = true;

        emit ProposalCancelled(proposalId);
    }

    function getProposalCount() external view returns (uint256) {
        return proposals.length;
    }

    receive() external payable {}
}
