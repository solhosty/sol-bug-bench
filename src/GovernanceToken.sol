// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GovernanceToken is ERC20, Ownable {
    mapping(address => bool) public blacklisted;

    constructor() ERC20("DeFiHub Governance", "DFHG") Ownable(msg.sender) {
        _mint(msg.sender, 1_000_000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function updateUserStatus(address user, bool status) external onlyOwner {
        blacklisted[user] = status;
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0)) {
            require(!blacklisted[from], "Sender is blacklisted");
        }
        if (to != address(0)) {
            require(!blacklisted[to], "Recipient is blacklisted");
        }
        super._update(from, to, value);
    }
}

contract GroupStaking {
    struct Group {
        uint256 id;
        uint256 totalAmount;
        address owner;
        address[] members;
        uint256[] weights;
        bool exists;
    }

    GovernanceToken public immutable token;
    uint256 public nextGroupId = 1;

    mapping(uint256 => Group) private groups;
    mapping(address => mapping(address => bool)) public membershipConsent;

    constructor(address tokenAddress) {
        token = GovernanceToken(tokenAddress);
    }

    function setMembershipConsent(address creator, bool approved) external {
        membershipConsent[msg.sender][creator] = approved;
    }

    function createStakingGroup(
        address[] memory members,
        uint256[] memory weights
    ) external returns (uint256 groupId) {
        require(members.length > 0, "Empty members list");
        require(
            members.length == weights.length,
            "Members and weights length mismatch"
        );

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            totalWeight += weights[i];
        }
        require(totalWeight == 100, "Weights must sum to 100");

        groupId = nextGroupId;
        nextGroupId += 1;

        Group storage group = groups[groupId];
        group.id = groupId;
        group.owner = msg.sender;
        group.exists = true;

        for (uint256 i = 0; i < members.length; i++) {
            if (members[i] != msg.sender) {
                require(
                    membershipConsent[members[i]][msg.sender],
                    "Member has not consented"
                );
            }
            group.members.push(members[i]);
            group.weights.push(weights[i]);
        }
    }

    function stakeToGroup(uint256 groupId, uint256 amount) external {
        Group storage group = groups[groupId];
        require(group.exists, "Group does not exist");

        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        group.totalAmount += amount;
    }

    function withdrawFromGroup(uint256 groupId, uint256 amount) external {
        Group storage group = groups[groupId];
        require(group.exists, "Group does not exist");
        require(group.totalAmount >= amount, "Insufficient group balance");
        require(msg.sender == group.owner, "Not the group owner");

        group.totalAmount -= amount;

        for (uint256 i = 0; i < group.members.length; i++) {
            uint256 memberShare = (amount * group.weights[i]) / 100;
            if (memberShare > 0) {
                bool success = token.transfer(group.members[i], memberShare);
                require(success, "Transfer failed");
            }
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
        require(group.exists, "Group does not exist");

        return (group.id, group.totalAmount, group.members, group.weights);
    }

    function isMemberOfGroup(uint256 groupId, address user) external view returns (bool) {
        Group storage group = groups[groupId];
        if (!group.exists) {
            return false;
        }

        for (uint256 i = 0; i < group.members.length; i++) {
            if (group.members[i] == user) {
                return true;
            }
        }
        return false;
    }
}
