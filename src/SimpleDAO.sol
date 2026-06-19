// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleDAO {
    struct Proposal {
        address proposer;
        string description;
        address target;
        bytes callData;
        uint256 value;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 deadline;
        bool executed;
        bool canceled;
    }

    mapping(address => uint256) public votingPower;
    uint256 public votingPeriod;
    uint256 public quorum;

    Proposal[] public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description,
        address indexed target,
        uint256 value,
        uint256 deadline
    );
    event Voted(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);

    modifier onlyMember() {
        require(votingPower[msg.sender] > 0, "Not a member");
        _;
    }

    constructor(
        address[] memory members,
        uint256[] memory powers,
        uint256 _votingPeriod,
        uint256 _quorum
    ) {
        require(members.length == powers.length, "Length mismatch");
        require(members.length > 0, "No members");

        for (uint256 i = 0; i < members.length; i++) {
            require(members[i] != address(0), "Invalid member");
            require(powers[i] > 0, "Zero power");
            votingPower[members[i]] = powers[i];
        }

        votingPeriod = _votingPeriod;
        quorum = _quorum;
    }

    function propose(
        string calldata description,
        address target,
        bytes calldata callData,
        uint256 value
    ) external onlyMember returns (uint256) {
        Proposal memory proposal = Proposal({
            proposer: msg.sender,
            description: description,
            target: target,
            callData: callData,
            value: value,
            yesVotes: 0,
            noVotes: 0,
            deadline: block.timestamp + votingPeriod,
            executed: false,
            canceled: false
        });

        proposals.push(proposal);
        uint256 proposalId = proposals.length - 1;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            description,
            target,
            value,
            proposal.deadline
        );

        return proposalId;
    }

    function vote(uint256 proposalId, bool support) external onlyMember {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp <= proposal.deadline, "Voting ended");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Proposal canceled");
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
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp > proposal.deadline, "Voting not ended");
        require(!proposal.executed, "Already executed");
        require(!proposal.canceled, "Proposal canceled");
        require(proposal.yesVotes >= quorum, "Quorum not reached");
        require(proposal.yesVotes > proposal.noVotes, "Proposal not passed");

        proposal.executed = true;

        (bool success,) = proposal.target.call{value: proposal.value}(proposal.callData);
        require(success, "Execution failed");

        emit ProposalExecuted(proposalId);
    }

    function cancel(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        require(msg.sender == proposal.proposer, "Not proposer");
        require(!proposal.executed, "Already executed");

        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    function getProposalCount() external view returns (uint256) {
        return proposals.length;
    }

    receive() external payable {}
}
