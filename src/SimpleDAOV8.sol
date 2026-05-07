// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SimpleDAOV8
 * @dev Minimal governance contract with weighted voting and proposal execution.
 */
contract SimpleDAOV8 {
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
    uint256 public totalVotingPower;
    uint256 private proposalCount;

    mapping(address => uint256) public votingPower;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address indexed target,
        uint256 value,
        uint256 deadline
    );
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId, address indexed proposer);

    modifier onlyMember() {
        require(votingPower[msg.sender] > 0, "Not a member");
        _;
    }

    /**
     * @dev Initializes DAO members and voting configuration.
     * @param members Member addresses.
     * @param votingPowers Voting power for each member.
     * @param votingPeriod_ Duration for voting on a proposal.
     * @param quorum_ Minimum yes-vote power required to execute.
     */
    constructor(
        address[] memory members,
        uint256[] memory votingPowers,
        uint256 votingPeriod_,
        uint256 quorum_
    ) {
        require(members.length > 0, "Empty members");
        require(members.length == votingPowers.length, "Length mismatch");

        for (uint256 i = 0; i < members.length; i++) {
            require(members[i] != address(0), "Invalid member");
            require(votingPowers[i] > 0, "Invalid voting power");
            require(votingPower[members[i]] == 0, "Duplicate member");

            votingPower[members[i]] = votingPowers[i];
            totalVotingPower += votingPowers[i];
        }

        require(votingPeriod_ > 0, "Invalid voting period");
        require(quorum_ > 0, "Invalid quorum");

        votingPeriod = votingPeriod_;
        quorum = quorum_;
    }

    /**
     * @dev Creates a new proposal.
     * @param target Contract address called on execution.
     * @param value ETH value sent on execution.
     * @param data Calldata sent to target.
     */
    function propose(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyMember returns (uint256 proposalId) {
        require(target != address(0), "Invalid target");

        proposalId = proposalCount;
        proposalCount++;

        Proposal storage proposal = proposals[proposalId];
        proposal.target = target;
        proposal.value = value;
        proposal.data = data;
        proposal.deadline = block.timestamp + votingPeriod;
        proposal.proposer = msg.sender;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            target,
            value,
            proposal.deadline
        );
    }

    /**
     * @dev Casts a yes/no vote weighted by member voting power.
     * @param proposalId Proposal identifier.
     * @param support True for yes vote, false for no vote.
     */
    function vote(uint256 proposalId, bool support) external onlyMember {
        Proposal storage proposal = proposals[proposalId];

        require(proposal.proposer != address(0), "Proposal does not exist");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.cancelled, "Proposal cancelled");
        require(block.timestamp <= proposal.deadline, "Voting ended");
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
     * @dev Executes a proposal after voting period if quorum and majority are met.
     * @param proposalId Proposal identifier.
     */
    function execute(uint256 proposalId) external onlyMember {
        Proposal storage proposal = proposals[proposalId];

        require(proposal.proposer != address(0), "Proposal does not exist");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.cancelled, "Proposal cancelled");
        require(block.timestamp > proposal.deadline, "Voting not ended");
        require(proposal.yesVotes >= quorum, "Quorum not met");
        require(proposal.yesVotes > proposal.noVotes, "Proposal rejected");

        proposal.executed = true;

        (bool success,) = proposal.target.call{value: proposal.value}(proposal.data);
        require(success, "Execution failed");

        emit ProposalExecuted(proposalId);
    }

    /**
     * @dev Cancels a proposal. Only proposer can cancel.
     * @param proposalId Proposal identifier.
     */
    function cancel(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        require(proposal.proposer != address(0), "Proposal does not exist");
        require(msg.sender == proposal.proposer, "Not proposer");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.cancelled, "Proposal already cancelled");
        require(block.timestamp <= proposal.deadline, "Voting ended");
        require(proposal.yesVotes == 0 && proposal.noVotes == 0, "Voting started");

        proposal.cancelled = true;
        emit ProposalCancelled(proposalId, msg.sender);
    }

    /**
     * @dev Returns the number of proposals created.
     */
    function getProposalCount() external view returns (uint256) {
        return proposalCount;
    }

    receive() external payable {}
}
