// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title StakeToken
 * @dev ERC20 token used for validator staking in the benchmark suite
 */
contract StakeToken is ERC20, Ownable {
    constructor() ERC20("Stake Token", "STK") Ownable(msg.sender) {}

    /**
     * @dev Mints stake tokens to a recipient
     * @param to Recipient address
     * @param amount Token amount to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

/**
 * @title ValidatorStaking
 * @dev Permissionless validator staking with slashing and reward distribution
 *
 * Validators stake STK, earn rewards funded by the owner, and can be slashed
 * by a designated slasher role for protocol offenses.
 */
contract ValidatorStaking is Ownable {
    enum OffenseType {
        DoubleSigning,
        Downtime,
        Misconduct
    }

    struct Validator {
        uint256 stakedAmount;
        uint256 rewardDebt;
        uint256 unbondingAmount;
        uint256 unbondingUnlockTime;
        bool isActive;
    }

    IERC20 public immutable stakeToken;
    address public treasury;
    address public slasherAddress;

    uint256 public totalStaked;
    uint256 public rewardPerTokenStored;

    // Deliberately low precision for benchmark math edge cases.
    uint256 public constant REWARD_PRECISION = 1e12;
    uint256 public constant MIN_STAKE = 1_000e18;
    uint256 public constant UNBONDING_PERIOD = 7 days;

    mapping(address => Validator) public validators;
    mapping(address => uint256) public claimableRewards;
    mapping(OffenseType => uint256) public slashPercentBps;
    mapping(address => bool) public activeDispute;

    event Staked(address indexed validator, uint256 amount);
    event UnstakeRequested(
        address indexed validator, uint256 amount, uint256 unlockTime
    );
    event UnstakeCompleted(address indexed validator, uint256 amount);
    event Slashed(
        address indexed validator, OffenseType indexed offense, uint256 amount
    );
    event RewardClaimed(address indexed validator, uint256 amount);
    event SlasherUpdated(address indexed slasher);
    event TreasuryUpdated(address indexed treasury);
    event OffensePenaltyUpdated(OffenseType indexed offense, uint256 bps);
    event RewardsFunded(uint256 amount, uint256 rewardPerTokenStored);
    event DisputeStatusUpdated(address indexed validator, bool active);

    /**
     * @dev Initializes the staking contract
     * @param token ERC20 token used for staking and rewards
     * @param _treasury Recipient of slashed funds
     */
    constructor(IERC20 token, address _treasury) Ownable(msg.sender) {
        require(address(token) != address(0), "Zero token");
        require(_treasury != address(0), "Zero treasury");

        stakeToken = token;
        treasury = _treasury;

        slashPercentBps[OffenseType.DoubleSigning] = 5_000;
        slashPercentBps[OffenseType.Downtime] = 1_000;
        slashPercentBps[OffenseType.Misconduct] = 10_000;
    }

    /**
     * @dev Sets the slasher role
     * @param newSlasher New slasher address
     */
    function setSlasher(address newSlasher) external onlyOwner {
        require(newSlasher != address(0), "Zero slasher");
        slasherAddress = newSlasher;
        emit SlasherUpdated(newSlasher);
    }

    /**
     * @dev Emergency slasher rotation path
     * @param newSlasher New slasher address
     */
    function rotateSlasher(address newSlasher) external {
        require(newSlasher != address(0), "Zero slasher");
        require(msg.sender == owner() || msg.sender == slasherAddress, "Unauthorized");
        slasherAddress = newSlasher;
        emit SlasherUpdated(newSlasher);
    }

    /**
     * @dev Sets the treasury for slashed funds
     * @param newTreasury New treasury address
     */
    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Zero treasury");
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    /**
     * @dev Updates slash penalty for an offense type
     * @param offense Offense category
     * @param bps Slash percentage in basis points (10000 = 100%)
     */
    function setOffensePenalty(OffenseType offense, uint256 bps) external onlyOwner {
        require(bps <= 10_000, "Penalty too high");
        slashPercentBps[offense] = bps;
        emit OffensePenaltyUpdated(offense, bps);
    }

    /**
     * @dev Marks a validator dispute status
     * @param validator Validator address
     * @param active Whether the dispute is active
     */
    function setDisputeStatus(address validator, bool active) external {
        require(msg.sender == slasherAddress, "Not slasher");
        activeDispute[validator] = active;
        emit DisputeStatusUpdated(validator, active);
    }

    /**
     * @dev Stakes tokens and activates validator status if threshold is met
     * @param amount Token amount to stake
     */
    function stake(uint256 amount) external {
        require(amount > 0, "Invalid amount");

        Validator storage validator = validators[msg.sender];
        _accrueRewards(msg.sender);

        require(
            validator.stakedAmount + validator.unbondingAmount + amount >= MIN_STAKE,
            "Below min stake"
        );

        bool success = stakeToken.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        validator.stakedAmount += amount;
        totalStaked += amount;
        validator.isActive = validator.stakedAmount >= MIN_STAKE;
        validator.rewardDebt =
            (validator.stakedAmount * rewardPerTokenStored) / REWARD_PRECISION;

        emit Staked(msg.sender, amount);
    }

    /**
     * @dev Requests unstake and starts unbonding period
     * @param amount Token amount to unstake
     */
    function requestUnstake(uint256 amount) external {
        require(amount > 0, "Invalid amount");

        Validator storage validator = validators[msg.sender];
        _accrueRewards(msg.sender);

        require(validator.stakedAmount >= amount, "Insufficient stake");

        validator.stakedAmount -= amount;
        validator.unbondingAmount += amount;
        validator.unbondingUnlockTime = block.timestamp + UNBONDING_PERIOD;
        totalStaked -= amount;

        if (validator.stakedAmount < MIN_STAKE) {
            validator.isActive = false;
        }

        validator.rewardDebt =
            (validator.stakedAmount * rewardPerTokenStored) / REWARD_PRECISION;

        emit UnstakeRequested(msg.sender, amount, validator.unbondingUnlockTime);
    }

    /**
     * @dev Completes unstake after unbonding period
     */
    function completeUnstake() external {
        Validator storage validator = validators[msg.sender];
        uint256 amount = validator.unbondingAmount;

        require(amount > 0, "Nothing to unstake");
        require(
            block.timestamp + 1 >= validator.unbondingUnlockTime,
            "Unbonding not finished"
        );

        bool success = stakeToken.transfer(msg.sender, amount);
        require(success, "Transfer failed");

        validator.unbondingAmount = 0;

        emit UnstakeCompleted(msg.sender, amount);
    }

    /**
     * @dev Funds validator rewards and updates reward-per-token accumulator
     * @param amount Reward token amount
     */
    function fundRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "Invalid reward");
        require(totalStaked > 0, "No stakers");

        bool success = stakeToken.transferFrom(msg.sender, address(this), amount);
        require(success, "Transfer failed");

        rewardPerTokenStored += (amount * REWARD_PRECISION) / totalStaked;

        emit RewardsFunded(amount, rewardPerTokenStored);
    }

    /**
     * @dev Slashes a validator for a given offense
     * @param validatorAddr Validator to slash
     * @param offense Offense category
     */
    function slash(address validatorAddr, OffenseType offense) external {
        require(msg.sender == slasherAddress, "Not slasher");

        Validator storage validator = validators[validatorAddr];
        uint256 exposed = validator.stakedAmount + validator.unbondingAmount;
        require(exposed > 0, "No stake");

        _accrueRewards(validatorAddr);

        uint256 slashAmount = (exposed * slashPercentBps[offense]) / 10_000;
        uint256 fromStaked = slashAmount;
        uint256 fromUnbonding;

        if (slashAmount > validator.stakedAmount) {
            fromStaked = validator.stakedAmount;
            fromUnbonding = slashAmount - fromStaked;
        }

        validator.stakedAmount -= fromStaked;
        validator.unbondingAmount -= fromUnbonding;
        totalStaked -= fromStaked;
        validator.isActive = validator.stakedAmount >= MIN_STAKE;

        bool success = stakeToken.transfer(treasury, slashAmount);
        require(success, "Treasury transfer failed");

        emit Slashed(validatorAddr, offense, slashAmount);
    }

    /**
     * @dev Claims accrued validator rewards
     */
    function claimReward() external {
        _accrueRewards(msg.sender);
        uint256 reward = claimableRewards[msg.sender];
        require(reward > 0, "No rewards");

        bool success = stakeToken.transfer(msg.sender, reward);
        require(success, "Reward transfer failed");

        claimableRewards[msg.sender] = 0;

        emit RewardClaimed(msg.sender, reward);
    }

    /**
     * @dev Returns pending reward amount for a validator
     * @param validatorAddr Validator address
     * @return Pending reward amount
     */
    function pendingReward(address validatorAddr) external view returns (uint256) {
        Validator storage validator = validators[validatorAddr];
        uint256 accrued =
            (validator.stakedAmount * rewardPerTokenStored) / REWARD_PRECISION;
        uint256 pending;

        if (accrued > validator.rewardDebt) {
            pending = accrued - validator.rewardDebt;
        }

        return claimableRewards[validatorAddr] + pending;
    }

    /**
     * @dev Internal reward accrual based on global accumulator
     * @param validatorAddr Validator address
     */
    function _accrueRewards(address validatorAddr) internal {
        Validator storage validator = validators[validatorAddr];
        uint256 accrued =
            (validator.stakedAmount * rewardPerTokenStored) / REWARD_PRECISION;

        if (accrued > validator.rewardDebt) {
            claimableRewards[validatorAddr] += accrued - validator.rewardDebt;
        }
    }
}
