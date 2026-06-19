// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SimpleDAOV2
 * @dev Member-governed DAO with weighted voting and proposal execution.
 */
contract SimpleDAOV2 {
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

    uint256 public totalVotingPower;
    uint256 public immutable votingPeriod;
    uint256 public immutable quorum;

    Proposal[] private proposals;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address indexed target,
        uint256 value,
        uint256 deadline,
        bytes data
    );
    event Voted(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 votingPower
    );
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    modifier onlyMember() {
        require(votingPower[msg.sender] > 0, "Not a member");
        _;
    }

    /**
     * @param members The member addresses.
     * @param votingPowers The voting power for each member.
     * @param votingPeriod_ Voting period in seconds.
     * @param quorum_ Minimum total votes (yes + no) required.
     */
    constructor(
        address[] memory members,
        uint256[] memory votingPowers,
        uint256 votingPeriod_,
        uint256 quorum_
    ) {
        require(members.length > 0, "No members");
        require(members.length == votingPowers.length, "Length mismatch");
        require(votingPeriod_ > 0, "Invalid voting period");

        for (uint256 i = 0; i < members.length; i++) {
            require(members[i] != address(0), "Invalid member");
            require(votingPower[members[i]] == 0, "Duplicate member");
            require(votingPowers[i] > 0, "Invalid voting power");

            votingPower[members[i]] = votingPowers[i];
            totalVotingPower += votingPowers[i];
        }

        require(quorum_ > 0, "Invalid quorum");
        require(quorum_ <= totalVotingPower, "Quorum too high");

        votingPeriod = votingPeriod_;
        quorum = quorum_;
    }

    receive() external payable {}

    /**
     * @dev Creates a new proposal.
     */
    function propose(address target, uint256 value, bytes calldata data)
        external
        onlyMember
        returns (uint256 proposalId)
    {
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
            block.timestamp + votingPeriod,
            data
        );
    }

    /**
     * @dev Casts a weighted vote on an active proposal.
     */
    function vote(uint256 proposalId, bool support) external onlyMember {
        Proposal storage proposal = proposals[proposalId];

        require(proposal.proposer != address(0), "Proposal does not exist");
        require(block.timestamp <= proposal.deadline, "Voting ended");
        require(!proposal.cancelled, "Proposal cancelled");
        require(!proposal.executed, "Proposal executed");
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

    /**
     * @dev Executes a successful proposal while it is still active.
     */
    function execute(uint256 proposalId) external onlyMember {
        Proposal storage proposal = proposals[proposalId];

        require(proposal.proposer != address(0), "Proposal does not exist");
        require(block.timestamp <= proposal.deadline, "Proposal expired");
        require(!proposal.cancelled, "Proposal cancelled");
        require(!proposal.executed, "Proposal executed");

        uint256 totalVotes = proposal.yesVotes + proposal.noVotes;
        require(totalVotes >= quorum, "Quorum not met");
        require(proposal.yesVotes > proposal.noVotes, "Proposal not approved");

        proposal.executed = true;

        (bool success,) = proposal.target.call{value: proposal.value}(proposal.data);
        require(success, "Execution failed");

        emit ProposalExecuted(proposalId);
    }

    /**
     * @dev Cancels an active proposal. Only the proposer can cancel.
     */
    function cancel(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        require(proposal.proposer != address(0), "Proposal does not exist");
        require(msg.sender == proposal.proposer, "Not proposer");
        require(!proposal.cancelled, "Proposal cancelled");
        require(!proposal.executed, "Proposal executed");

        proposal.cancelled = true;

        emit ProposalCancelled(proposalId);
    }

    function getProposalCount() external view returns (uint256) {
        return proposals.length;
    }

    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        return proposals[proposalId];
    }
}
