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

    function updateUserStatus(address user, bool isBlacklisted) external {
        blacklisted[user] = isBlacklisted;
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && blacklisted[from]) {
            revert("Sender is blacklisted");
        }
        if (to != address(0) && blacklisted[to]) {
            revert("Recipient is blacklisted");
        }
        super._update(from, to, value);
    }
}

contract GroupStaking {
    struct StakingGroup {
        uint256 id;
        uint256 totalAmount;
        address owner;
        address[] members;
        uint256[] weights;
        bool exists;
    }

    GovernanceToken public immutable token;
    uint256 private nextGroupId;

    mapping(uint256 => StakingGroup) private groups;
    mapping(uint256 => mapping(address => bool)) private groupMembers;

    constructor(address tokenAddress) {
        token = GovernanceToken(tokenAddress);
        nextGroupId = 1;
    }

    function createStakingGroup(address[] memory members, uint256[] memory weights)
        external
        returns (uint256 groupId)
    {
        if (members.length == 0) revert("Empty members list");
        if (members.length != weights.length) {
            revert("Members and weights length mismatch");
        }

        uint256 totalWeight;
        for (uint256 i = 0; i < weights.length; i++) {
            totalWeight += weights[i];
        }
        if (totalWeight != 100) revert("Weights must sum to 100");

        groupId = nextGroupId++;
        StakingGroup storage group = groups[groupId];
        group.id = groupId;
        group.totalAmount = 0;
        group.owner = msg.sender;
        group.exists = true;

        for (uint256 i = 0; i < members.length; i++) {
            group.members.push(members[i]);
            group.weights.push(weights[i]);
            groupMembers[groupId][members[i]] = true;
        }
    }

    function stakeToGroup(uint256 groupId, uint256 amount) external {
        StakingGroup storage group = groups[groupId];
        if (!group.exists) revert("Group does not exist");

        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        group.totalAmount += amount;
    }

    function withdrawFromGroup(uint256 groupId, uint256 amount) external {
        StakingGroup storage group = groups[groupId];
        if (!group.exists) revert("Group does not exist");
        if (msg.sender != group.owner) revert("Not the group owner");
        if (group.totalAmount < amount) revert("Insufficient group balance");

        group.totalAmount -= amount;
        uint256 membersLength = group.members.length;
        for (uint256 i = 0; i < membersLength; i++) {
            uint256 memberAmount = (amount * group.weights[i]) / 100;
            require(token.transfer(group.members[i], memberAmount), "Transfer failed");
        }
    }

    function getGroupInfo(uint256 groupId)
        external
        view
        returns (
            uint256 id,
            uint256 totalAmount,
            address[] memory members,
            uint256[] memory weights
        )
    {
        StakingGroup storage group = groups[groupId];
        if (!group.exists) revert("Group does not exist");

        return (group.id, group.totalAmount, group.members, group.weights);
    }

    function isMemberOfGroup(uint256 groupId, address user) external view returns (bool) {
        return groupMembers[groupId][user];
    }
}
