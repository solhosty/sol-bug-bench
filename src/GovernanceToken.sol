// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GovernanceToken is ERC20 {
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InvalidSpender(address spender);

    mapping(address => bool) public blacklisted;

    constructor() ERC20("DeFiHub Governance", "DFHG") {
        _mint(msg.sender, 1_000_000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function updateUserStatus(address user, bool status) external {
        blacklisted[user] = status;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        address sender = _msgSender();
        if (sender == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        uint256 senderBalance = balanceOf(sender);
        if (senderBalance < value) {
            revert ERC20InsufficientBalance(sender, senderBalance, value);
        }

        return super.transfer(to, value);
    }

    function approve(address spender, uint256 value) public override returns (bool) {
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }

        return super.approve(spender, value);
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        uint256 currentAllowance = allowance(from, _msgSender());
        if (currentAllowance < value) {
            revert ERC20InsufficientAllowance(_msgSender(), currentAllowance, value);
        }

        uint256 fromBalance = balanceOf(from);
        if (fromBalance < value) {
            revert ERC20InsufficientBalance(from, fromBalance, value);
        }

        return super.transferFrom(from, to, value);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        if (from != address(0)) {
            require(!blacklisted[from], "Sender is blacklisted");
        }
        if (to != address(0)) {
            require(!blacklisted[to], "Recipient is blacklisted");
        }
        super._beforeTokenTransfer(from, to, amount);
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

    constructor(address tokenAddress) {
        token = GovernanceToken(tokenAddress);
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
