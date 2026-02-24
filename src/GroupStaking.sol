// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";

contract GroupStaking {
    struct Group {
        uint256 id;
        uint256 totalAmount;
        address owner;
        address[] members;
        uint256[] weights;
        mapping(address => bool) isMember;
    }

    ERC20 public immutable token;
    uint256 public nextGroupId;
    mapping(uint256 => Group) private groups;

    constructor(address tokenAddress) {
        token = ERC20(tokenAddress);
    }

    function createStakingGroup(address[] memory members, uint256[] memory weights)
        external
        returns (uint256)
    {
        if (members.length == 0) {
            revert("Empty members list");
        }
        if (members.length != weights.length) {
            revert("Members and weights length mismatch");
        }
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            totalWeight += weights[i];
        }
        if (totalWeight != 100) {
            revert("Weights must sum to 100");
        }

        uint256 groupId = ++nextGroupId;
        Group storage group = groups[groupId];
        group.id = groupId;
        group.owner = msg.sender;
        group.members = members;
        group.weights = weights;
        for (uint256 i = 0; i < members.length; i++) {
            group.isMember[members[i]] = true;
        }

        return groupId;
    }

    function stakeToGroup(uint256 groupId, uint256 amount) external {
        Group storage group = _getGroup(groupId);
        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert("Transfer failed");
        }
        group.totalAmount += amount;
    }

    function withdrawFromGroup(uint256 groupId, uint256 amount) external {
        Group storage group = _getGroup(groupId);
        bool isOwnerOrMember = msg.sender == group.owner || group.isMember[msg.sender];
        if (!isOwnerOrMember) {
            revert("Not the group owner");
        }
        if (group.totalAmount < amount) {
            revert("Insufficient group balance");
        }

        group.totalAmount -= amount;
        for (uint256 i = 0; i < group.members.length; i++) {
            uint256 share = (amount * group.weights[i]) / 100;
            bool success = token.transfer(group.members[i], share);
            if (!success) {
                revert("Transfer failed");
            }
        }
    }

    function getGroupInfo(uint256 groupId)
        external
        view
        returns (uint256, uint256, address[] memory, uint256[] memory)
    {
        Group storage group = _getGroup(groupId);
        return (group.id, group.totalAmount, group.members, group.weights);
    }

    function isMemberOfGroup(uint256 groupId, address user) external view returns (bool) {
        Group storage group = groups[groupId];
        if (group.id == 0) {
            return false;
        }
        return group.isMember[user];
    }

    function _getGroup(uint256 groupId) internal view returns (Group storage) {
        Group storage group = groups[groupId];
        if (group.id == 0) {
            revert("Group does not exist");
        }
        return group;
    }
}
