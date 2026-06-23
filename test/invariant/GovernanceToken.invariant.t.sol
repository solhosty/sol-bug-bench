// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/GovernanceToken.sol";

/// @dev Exercises GroupStaking with valid (weights == 100) groups so the
///      stateful invariant fuzzer drives stake/withdraw flows.
contract GroupStakingHandler is Test {
    GovernanceToken public token;
    GroupStaking public staking;

    uint256[] public groupIds;
    address[] internal members;

    constructor(GovernanceToken token_, GroupStaking staking_) {
        token = token_;
        staking = staking_;
        members = [address(0xA1), address(0xA2), address(0xA3)];
    }

    function createGroup(uint256 weightSeed) external {
        uint256[] memory weights = new uint256[](3);
        // Always sums to 100.
        weights[0] = bound(weightSeed, 1, 98);
        weights[1] =
            bound(uint256(keccak256(abi.encode(weightSeed))), 1, 99 - weights[0]);
        weights[2] = 100 - weights[0] - weights[1];

        uint256 id = staking.createStakingGroup(members, weights);
        groupIds.push(id);
    }

    function stake(uint256 groupSeed, uint256 amount) external {
        if (groupIds.length == 0) return;
        uint256 id = groupIds[groupSeed % groupIds.length];
        amount = bound(amount, 1, 1_000 ether);

        token.mint(address(this), amount);
        token.approve(address(staking), amount);
        staking.stakeToGroup(id, amount);
    }

    function withdraw(uint256 groupSeed, uint256 amount) external {
        if (groupIds.length == 0) return;
        uint256 id = groupIds[groupSeed % groupIds.length];
        (, uint256 total,,) = staking.getGroupInfo(id);
        if (total == 0) return;
        staking.withdrawFromGroup(id, bound(amount, 1, total));
    }

    function groupCount() external view returns (uint256) {
        return groupIds.length;
    }
}

contract GovernanceTokenInvariantTest is Test {
    GovernanceToken public token;
    GroupStaking public staking;
    GroupStakingHandler public handler;

    function setUp() public {
        token = new GovernanceToken();
        staking = new GroupStaking(address(token));
        handler = new GroupStakingHandler(token, staking);
        targetContract(address(handler));
    }

    /// GS-G2: every existing group's weights must always sum to exactly 100.
    /// This is enforced at creation and never mutated, so it holds.
    function invariant_GS_G2_weightsSumTo100() public view {
        uint256 count = handler.groupCount();
        for (uint256 i = 0; i < count; i++) {
            uint256 id = handler.groupIds(i);
            (,,, uint256[] memory weights) = staking.getGroupInfo(id);
            uint256 sum;
            for (uint256 j = 0; j < weights.length; j++) {
                sum += weights[j];
            }
            assertEq(sum, 100);
        }
    }

    // --- Violation proofs (expected-broken invariants) ---

    /// GT-G1: total supply must only grow via an authorized minter.
    /// `mint` has no access control.
    function test_GT_G1_anyoneCanMint() public {
        uint256 before = token.totalSupply();
        address stranger = address(0xDEAD);

        vm.prank(stranger);
        token.mint(stranger, 1_000_000 ether);

        assertEq(token.totalSupply(), before + 1_000_000 ether);
        assertEq(token.balanceOf(stranger), 1_000_000 ether);
    }

    /// GT-G2: only a privileged admin may change blacklist status.
    /// Non-owner calls must revert.
    function test_GT_G2_anyoneCanBlacklist() public {
        address victim = address(0xCAFE);
        address stranger = address(0xDEAD);

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("OwnableUnauthorizedAccount(address)")),
                stranger
            )
        );
        token.updateUserStatus(victim, true);
    }

    /// GS-G1: the staking contract's token balance must equal the sum of all
    /// group `totalAmount`s. Per-member truncation strands dust that the
    /// accounting assumes was distributed.
    function test_GS_G1_withdrawalDustBreaksAccounting() public {
        address[] memory m = new address[](3);
        m[0] = address(0xA1);
        m[1] = address(0xA2);
        m[2] = address(0xA3);
        uint256[] memory w = new uint256[](3);
        w[0] = 34;
        w[1] = 33;
        w[2] = 33;

        uint256 id = staking.createStakingGroup(m, w);

        token.approve(address(staking), 100);
        staking.stakeToGroup(id, 100);

        staking.withdrawFromGroup(id, 99); // distributes 33 + 32 + 32 = 97

        (, uint256 total,,) = staking.getGroupInfo(id);
        // Accounting says 1 remains; the contract actually holds 3 (dust = 2).
        assertEq(total, 1);
        assertEq(token.balanceOf(address(staking)), 3);
        assertTrue(token.balanceOf(address(staking)) != total);
    }

    /// GS-F1: a withdrawal must not be permanently blockable by a single
    /// member's state. Blacklisting one member reverts the whole distribution,
    /// freezing the group's funds.
    function test_GS_F1_blacklistedMemberFreezesGroup() public {
        address[] memory m = new address[](3);
        m[0] = address(0xA1);
        m[1] = address(0xA2);
        m[2] = address(0xA3);
        uint256[] memory w = new uint256[](3);
        w[0] = 34;
        w[1] = 33;
        w[2] = 33;

        uint256 id = staking.createStakingGroup(m, w);
        token.approve(address(staking), 100);
        staking.stakeToGroup(id, 100);

        // Anyone can blacklist a member (see GT-G2).
        token.updateUserStatus(m[0], true);

        vm.expectRevert(bytes("Recipient is blacklisted"));
        staking.withdrawFromGroup(id, 100);
    }
}
