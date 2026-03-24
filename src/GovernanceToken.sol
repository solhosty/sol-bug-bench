// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GovernanceToken is ERC20 {
    mapping(address => bool) public blacklisted;

    constructor() ERC20("GovernanceToken", "GOV") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function updateUserStatus(address user, bool status) external {
        blacklisted[user] = status;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        require(!blacklisted[msg.sender], "Sender is blacklisted");
        require(!blacklisted[to], "Recipient is blacklisted");
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        require(!blacklisted[from], "Sender is blacklisted");
        require(!blacklisted[to], "Recipient is blacklisted");
        return super.transferFrom(from, to, value);
    }
}

contract GroupStaking {
    struct Group {
        uint256 id;
        address owner;
        uint256 totalAmount;
        address[] members;
        uint256[] weights;
    }

    GovernanceToken public immutable token;
    uint256 public nextGroupId = 1;

    mapping(uint256 => Group) private groups;
    mapping(uint256 => mapping(address => bool)) private membersByGroup;

    constructor(address tokenAddress) {
        token = GovernanceToken(tokenAddress);
    }

    function createStakingGroup(
        address[] memory members,
        uint256[] memory weights
    ) external returns (uint256 groupId) {
        require(members.length > 0, "Empty members list");
        require(members.length == weights.length, "Members and weights length mismatch");

        uint256 totalWeight;
        for (uint256 i = 0; i < weights.length; i++) {
            totalWeight += weights[i];
        }
        require(totalWeight == 100, "Weights must sum to 100");

        groupId = nextGroupId++;
        Group storage group = groups[groupId];
        group.id = groupId;
        group.owner = msg.sender;
        group.members = members;
        group.weights = weights;

        for (uint256 i = 0; i < members.length; i++) {
            membersByGroup[groupId][members[i]] = true;
        }
    }

    function stakeToGroup(uint256 groupId, uint256 amount) external {
        Group storage group = groups[groupId];
        require(group.id != 0, "Group does not exist");

        token.transferFrom(msg.sender, address(this), amount);
        group.totalAmount += amount;
    }

    function withdrawFromGroup(uint256 groupId, uint256 amount) external {
        Group storage group = groups[groupId];
        require(group.id != 0, "Group does not exist");
        require(group.totalAmount >= amount, "Insufficient group balance");
        require(group.owner == msg.sender, "Not the group owner");

        group.totalAmount -= amount;

        for (uint256 i = 0; i < group.members.length; i++) {
            uint256 memberShare = (amount * group.weights[i]) / 100;
            token.transfer(group.members[i], memberShare);
        }
    }

    function getGroupInfo(
        uint256 groupId
    )
        external
        view
        returns (
            uint256 id,
            uint256 totalAmount,
            address[] memory members,
            uint256[] memory weights
        )
    {
        Group storage group = groups[groupId];
        require(group.id != 0, "Group does not exist");
        return (group.id, group.totalAmount, group.members, group.weights);
    }

    function isMemberOfGroup(uint256 groupId, address user) external view returns (bool) {
        return membersByGroup[groupId][user];
    }
}
