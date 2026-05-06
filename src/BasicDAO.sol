// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

contract BasicDAO {
    struct Proposal {
        address proposer;
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 deadline;
        bool executed;
    }

    address public owner;
    mapping(address => bool) public isMember;
    Proposal[] public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event MemberAdded(address indexed member);
    event MemberRemoved(address indexed member);
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description
    );
    event Voted(uint256 indexed proposalId, address indexed voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyMember() {
        require(isMember[msg.sender], "Only member");
        _;
    }

    modifier proposalExists(uint256 proposalId) {
        require(proposalId < proposals.length, "Invalid proposal");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addMember(address member) external onlyOwner {
        isMember[member] = true;
        emit MemberAdded(member);
    }

    function removeMember(address member) external onlyOwner {
        isMember[member] = false;
        emit MemberRemoved(member);
    }

    function createProposal(string memory description, uint256 votingPeriod)
        external
        onlyMember
        returns (uint256)
    {
        proposals.push(
            Proposal({
                proposer: msg.sender,
                description: description,
                yesVotes: 0,
                noVotes: 0,
                deadline: block.timestamp + votingPeriod,
                executed: false
            })
        );

        uint256 proposalId = proposals.length - 1;
        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }

    function vote(uint256 proposalId, bool support)
        external
        onlyMember
        proposalExists(proposalId)
    {
        Proposal storage proposal = proposals[proposalId];

        // forge-lint: disable-next-line(block-timestamp)
        require(block.timestamp < proposal.deadline, "Voting ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        hasVoted[proposalId][msg.sender] = true;

        if (support) {
            proposal.yesVotes += 1;
        } else {
            proposal.noVotes += 1;
        }

        emit Voted(proposalId, msg.sender, support);
    }

    function execute(uint256 proposalId) external proposalExists(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(!proposal.executed, "Already executed");
        // forge-lint: disable-next-line(block-timestamp)
        require(block.timestamp >= proposal.deadline, "Proposal still active");
        require(proposal.yesVotes > proposal.noVotes, "Proposal did not pass");

        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }
}
