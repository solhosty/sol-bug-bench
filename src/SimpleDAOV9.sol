// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title SimpleDAOV9
/// @notice Minimal DAO governance with member-gated proposals and voting.
contract SimpleDAOV9 {
    struct Proposal {
        uint256 id;
        address proposer;
        address target;
        uint256 value;
        bytes data;
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 deadline;
        bool executed;
    }

    uint256 public immutable votingPeriod;
    uint256 public immutable memberCount;
    uint256 public proposalCount;

    mapping(address => bool) public isMember;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address indexed target,
        uint256 value,
        string description,
        uint256 deadline
    );
    event Voted(uint256 indexed proposalId, address indexed voter, bool support);
    event Executed(uint256 indexed proposalId);

    modifier onlyMember() {
        require(isMember[msg.sender], "Not a member");
        _;
    }

    /// @notice Initializes DAO members and voting period.
    /// @param members Initial member addresses.
    /// @param votingPeriod_ Voting duration for each proposal.
    constructor(address[] memory members, uint256 votingPeriod_) {
        require(members.length > 0, "Empty members");
        require(votingPeriod_ > 0, "Invalid voting period");

        for (uint256 i = 0; i < members.length; i++) {
            address member = members[i];
            require(member != address(0), "Invalid member");
            require(!isMember[member], "Duplicate member");
            isMember[member] = true;
        }

        votingPeriod = votingPeriod_;
        memberCount = members.length;
    }

    /// @notice Creates a new proposal.
    /// @param target Contract address called when executing the proposal.
    /// @param value ETH value sent with the call.
    /// @param data Calldata sent to target.
    /// @param description Human-readable proposal description.
    /// @return proposalId Identifier for the created proposal.
    function propose(
        address target,
        uint256 value,
        bytes calldata data,
        string calldata description
    ) external onlyMember returns (uint256 proposalId) {
        proposalId = proposalCount;
        proposalCount += 1;

        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.target = target;
        proposal.value = value;
        proposal.data = data;
        proposal.description = description;
        proposal.deadline = block.timestamp + votingPeriod;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            target,
            value,
            description,
            proposal.deadline
        );
    }

    /// @notice Casts a vote for or against a proposal.
    /// @param proposalId Proposal identifier.
    /// @param support True for yes vote, false for no vote.
    function vote(uint256 proposalId, bool support) external onlyMember {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.proposer != address(0), "Proposal does not exist");
        require(block.timestamp < proposal.deadline, "Voting has ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        hasVoted[proposalId][msg.sender] = true;

        if (support) {
            proposal.yesVotes += 1;
        } else {
            proposal.noVotes += 1;
        }

        emit Voted(proposalId, msg.sender, support);
    }

    /// @notice Executes a successful proposal after the voting deadline.
    /// @param proposalId Proposal identifier.
    function execute(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.proposer != address(0), "Proposal does not exist");
        require(block.timestamp >= proposal.deadline, "Voting is still active");
        require(proposal.yesVotes > proposal.noVotes, "Proposal not passed");
        require(proposal.yesVotes * 2 > memberCount, "Insufficient approvals");
        require(!proposal.executed, "Proposal already executed");

        proposal.executed = true;
        (bool success,) = proposal.target.call{value: proposal.value}(proposal.data);
        require(success, "Execution failed");

        emit Executed(proposalId);
    }

    receive() external payable {}
}
