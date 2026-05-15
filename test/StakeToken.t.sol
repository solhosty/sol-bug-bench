// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/StakeToken.sol";

contract StakeTokenTest is Test {
    StakeToken public token;
    ValidatorStaking public staking;

    address public treasury;
    address public slasher;
    address public validator1;
    address public validator2;
    address public outsider;

    function setUp() public {
        treasury = makeAddr("treasury");
        slasher = makeAddr("slasher");
        validator1 = makeAddr("validator1");
        validator2 = makeAddr("validator2");
        outsider = makeAddr("outsider");

        token = new StakeToken();
        staking = new ValidatorStaking(IERC20(address(token)), treasury);
        staking.setSlasher(slasher);

        token.mint(address(this), 50_000e18);
        token.mint(validator1, 10_000e18);
        token.mint(validator2, 10_000e18);

        vm.prank(validator1);
        token.approve(address(staking), type(uint256).max);

        vm.prank(validator2);
        token.approve(address(staking), type(uint256).max);

        token.approve(address(staking), type(uint256).max);
    }

    function testStake() public {
        vm.prank(validator1);
        staking.stake(1_500e18);

        (uint256 stakedAmount,, uint256 unbondingAmount,, bool isActive) =
            staking.validators(validator1);

        assertEq(stakedAmount, 1_500e18);
        assertEq(unbondingAmount, 0);
        assertTrue(isActive);
        assertEq(staking.totalStaked(), 1_500e18);
    }

    function test_RevertWhen_StakeBelowMinimum() public {
        vm.prank(validator1);
        vm.expectRevert("Below min stake");
        staking.stake(500e18);
    }

    function testMultipleStakeCalls() public {
        vm.startPrank(validator1);
        staking.stake(1_000e18);
        staking.stake(250e18);
        vm.stopPrank();

        (uint256 stakedAmount,,,,) = staking.validators(validator1);
        assertEq(stakedAmount, 1_250e18);
        assertEq(staking.totalStaked(), 1_250e18);
    }

    function testRequestUnstakeAndCompleteAfterUnbonding() public {
        vm.startPrank(validator1);
        staking.stake(2_000e18);
        staking.requestUnstake(500e18);

        (, uint256 rewardDebt, uint256 unbondingAmount, uint256 unlockTime,) =
            staking.validators(validator1);

        assertEq(unbondingAmount, 500e18);
        assertEq(unlockTime, block.timestamp + staking.UNBONDING_PERIOD());
        assertEq(rewardDebt, 0);

        skip(staking.UNBONDING_PERIOD());
        uint256 balanceBefore = token.balanceOf(validator1);

        staking.completeUnstake();
        vm.stopPrank();

        assertEq(token.balanceOf(validator1), balanceBefore + 500e18);
    }

    function test_RevertWhen_CompleteUnstakeBeforeUnbondingEnds() public {
        vm.startPrank(validator1);
        staking.stake(2_000e18);
        staking.requestUnstake(400e18);

        skip(staking.UNBONDING_PERIOD() - 2);

        vm.expectRevert("Unbonding not finished");
        staking.completeUnstake();
        vm.stopPrank();
    }

    function testSlashHappyPath() public {
        vm.prank(validator1);
        staking.stake(2_000e18);

        uint256 treasuryBefore = token.balanceOf(treasury);

        vm.prank(slasher);
        staking.slash(validator1, ValidatorStaking.OffenseType.DoubleSigning);

        (uint256 stakedAmount,,,,) = staking.validators(validator1);

        assertEq(stakedAmount, 1_000e18);
        assertEq(token.balanceOf(treasury), treasuryBefore + 1_000e18);
    }

    function test_RevertWhen_SlashByNonSlasher() public {
        vm.prank(validator1);
        staking.stake(2_000e18);

        vm.prank(outsider);
        vm.expectRevert("Not slasher");
        staking.slash(validator1, ValidatorStaking.OffenseType.Downtime);
    }

    function testDoubleSlashSameOffense() public {
        vm.prank(validator1);
        staking.stake(2_000e18);

        vm.startPrank(slasher);
        staking.slash(validator1, ValidatorStaking.OffenseType.Downtime);
        staking.slash(validator1, ValidatorStaking.OffenseType.Downtime);
        vm.stopPrank();

        (uint256 stakedAmount,,,,) = staking.validators(validator1);

        assertEq(stakedAmount, 1_620e18);
    }

    function testSlashCanReduceUnbondingBalance() public {
        vm.startPrank(validator1);
        staking.stake(2_000e18);
        staking.requestUnstake(1_500e18);
        vm.stopPrank();

        vm.prank(slasher);
        staking.slash(validator1, ValidatorStaking.OffenseType.Misconduct);

        (uint256 stakedAmount,, uint256 unbondingAmount,, bool isActive) =
            staking.validators(validator1);

        assertEq(stakedAmount, 0);
        assertEq(unbondingAmount, 0);
        assertFalse(isActive);
    }

    function testRequestUnstakeWhileDisputed() public {
        vm.prank(validator1);
        staking.stake(2_000e18);

        vm.prank(slasher);
        staking.setDisputeStatus(validator1, true);

        vm.prank(validator1);
        staking.requestUnstake(200e18);

        (,, uint256 unbondingAmount,,) = staking.validators(validator1);
        assertEq(unbondingAmount, 200e18);
        assertTrue(staking.activeDispute(validator1));
    }

    function testFundRewardsAndClaim() public {
        vm.prank(validator1);
        staking.stake(1_000e18);

        vm.prank(validator2);
        staking.stake(1_000e18);

        staking.fundRewards(1_000e18);

        vm.prank(validator1);
        staking.claimReward();

        assertEq(staking.claimableRewards(validator1), 0);
        assertEq(token.balanceOf(validator1), 9_500e18);
    }

    function test_RevertWhen_ClaimRewardWithoutFunding() public {
        vm.prank(validator1);
        staking.stake(1_000e18);

        vm.prank(validator1);
        vm.expectRevert("No rewards");
        staking.claimReward();
    }

    function testRewardRoundingLeavesDust() public {
        vm.prank(validator1);
        staking.stake(1_000e18);

        vm.prank(validator2);
        staking.stake(1_000e18);

        staking.fundRewards(1);

        assertEq(staking.pendingReward(validator1), 0);
        assertEq(staking.pendingReward(validator2), 0);
        assertEq(token.balanceOf(address(staking)), 2_000e18 + 1);
    }

    function testSlasherCanRotateSlasherRole() public {
        address attacker = makeAddr("attacker");

        vm.prank(slasher);
        staking.rotateSlasher(attacker);

        assertEq(staking.slasherAddress(), attacker);
    }

    function test_RevertWhen_CompleteUnstakeWithoutRequest() public {
        vm.prank(validator1);
        vm.expectRevert("Nothing to unstake");
        staking.completeUnstake();
    }
}
