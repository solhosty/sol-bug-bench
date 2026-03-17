// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

interface ILiquidityPool {
    function lastDepositTime(address user) external view returns (uint256);

    function WITHDRAWAL_DELAY() external view returns (uint256);
}

/**
 * @title PoolShare
 * @dev ERC20 token representing ownership shares in the liquidity pool
 *
 * These tokens are minted when users deposit ETH and burned when they withdraw.
 * The supply directly correlates to the total liquidity provided to the protocol.
 */
contract PoolShare is ERC20Burnable, Ownable {
    ILiquidityPool public immutable pool;

    constructor(address poolAddress)
        ERC20("Liquidity Pool Share", "LPS")
        Ownable(msg.sender)
    {
        pool = ILiquidityPool(poolAddress);
    }

    /**
     * @dev Mints new pool share tokens
     * Only callable by the pool contract to maintain proper accounting
     * @param to The address to receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            require(
                block.timestamp >= pool.lastDepositTime(from) + pool.WITHDRAWAL_DELAY(),
                "Withdrawal delay not met"
            );
        }

        super._update(from, to, value);
    }
}

/**
 * @title LiquidityPool
 * @dev Core liquidity pool contract for the DeFiHub protocol
 *
 * Users can deposit ETH to earn rewards and receive proportional pool shares.
 * The pool implements a time-delay mechanism for withdrawals to ensure stability
 * and prevent flash loan attacks.
 */
contract LiquidityPool is Ownable {
    PoolShare public immutable shareToken;

    // User reward balances tracked separately for efficiency
    mapping(address => uint256) public rewards;
    // Nonces for signature verification to prevent replay attacks
    mapping(address => uint256) public nonces;
    // Timestamp tracking for withdrawal delay enforcement
    mapping(address => uint256) public lastDepositTime;

    // Security delay for withdrawals (24 hours)
    uint256 public constant WITHDRAWAL_DELAY = 1 days;
    // Reward rate as percentage of deposit (10%)
    uint256 public constant REWARD_RATE = 10;

    // Event declarations for comprehensive tracking
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdrawal(address indexed user, uint256 amount, uint256 shares);
    event RewardClaimed(address indexed user, uint256 amount);

    /**
     * @dev Initializes the liquidity pool and deploys the share token
     */
    constructor() Ownable(msg.sender) {
        shareToken = new PoolShare(address(this));
    }

    /**
     * @dev Allows users to deposit ETH and receive pool shares
     * Automatically calculates and allocates rewards based on deposit amount
     */
    function deposit() external payable {
        require(msg.value > 0, "Invalid deposit");
        _processDeposit(msg.sender, msg.value);
        lastDepositTime[msg.sender] = block.timestamp;
    }

    /**
     * @dev Allows deposits on behalf of other users
     * Useful for institutional integrations and third-party services
     * @param user The address that will receive the shares and rewards
     */
    function depositFor(address user) external payable {
        require(msg.value > 0, "Invalid deposit");
        _processDeposit(user, msg.value);
    }

    /**
     * @dev Withdraws ETH by burning pool shares
     * Enforces withdrawal delay for security against flash loan attacks
     * @param shares The number of pool shares to burn for withdrawal
     */
    function withdraw(uint256 shares) external {
        require(shareToken.balanceOf(msg.sender) >= shares, "Insufficient shares");

        // Enforce withdrawal delay for security
        require(
            block.timestamp >= lastDepositTime[msg.sender] + WITHDRAWAL_DELAY,
            "Withdrawal delay not met"
        );

        // Calculate ETH amount based on proportional share of pool
        uint256 amount = shares * address(this).balance / shareToken.totalSupply();

        // Transfer ETH to user
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        // Burn the shares to maintain proper accounting
        shareToken.transferFrom(msg.sender, address(this), shares);
        shareToken.burn(shares);
        emit Withdrawal(msg.sender, amount, shares);
    }

    /**
     * @dev Claims accumulated rewards using cryptographic signature verification
     * This secure method prevents unauthorized claims while allowing flexibility
     * @param user The user claiming rewards
     * @param amount The amount of rewards to claim
     * @param nonce The current nonce for replay protection
     * @param expiry The timestamp after which the signature is invalid
     * @param signature Cryptographic signature proving authorization
     */
    function claimReward(
        address user,
        uint256 amount,
        uint256 nonce,
        uint256 expiry,
        bytes memory signature
    ) external {
        require(rewards[user] >= amount, "Insufficient rewards");
        require(nonces[user] == nonce, "Invalid nonce");
        require(block.timestamp <= expiry, "Signature expired");

        // Verify cryptographic signature to prevent unauthorized claims
        bytes32 messageHash = keccak256(
            abi.encodePacked(address(this), block.chainid, user, amount, nonce, expiry)
        );
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        if (user.code.length > 0) {
            require(
                IERC1271(user).isValidSignature(ethHash, signature)
                    == IERC1271.isValidSignature.selector,
                "Invalid contract signature"
            );
        } else {
            require(ECDSA.recover(ethHash, signature) == user, "Invalid signature");
        }

        // Calculate protocol fee and user amount
        uint256 fee = (amount + 9) / 10; // 10% protocol fee, rounded up
        uint256 userAmount = amount - fee;
        require(userAmount + fee == amount, "Fee math error");

        rewards[user] -= amount;
        nonces[user] += 1;

        // Transfer protocol fee to treasury
        (bool feeSuccess,) = owner().call{value: fee}("");
        require(feeSuccess, "Fee transfer failed");

        // Transfer remaining amount to user
        (bool success,) = payable(user).call{value: userAmount}("");
        require(success, "User transfer failed");

        // Emit event for tracking reward claims
        emit RewardClaimed(user, userAmount);
    }

    /**
     * @dev Allows users to invalidate signed rewards by advancing their nonce
     * @param newNonce The new nonce value, must be greater than current
     */
    function cancelNonce(uint256 newNonce) external {
        require(newNonce > nonces[msg.sender], "new nonce must be greater");
        nonces[msg.sender] = newNonce;
    }

    /**
     * @dev Internal function to handle deposit logic for any user
     * Calculates shares, mints tokens, and allocates rewards
     * @param user The address receiving shares and rewards
     * @param amount The ETH amount being deposited
     */
    function _processDeposit(address user, uint256 amount) internal {
        // Calculate shares based on current pool ratio
        uint256 shares;
        uint256 totalSupply = shareToken.totalSupply();
        if (totalSupply == 0) {
            // First deposit gets 1:1 share ratio
            shares = amount;
        } else {
            // Subsequent deposits get proportional shares
            uint256 preBalance = address(this).balance - amount;
            require(preBalance > 0, "No pool balance");
            shares = (amount * totalSupply) / preBalance;
            require(shares > 0, "Deposit too small");
        }

        // Mint shares to the user
        shareToken.mint(user, shares);

        // Calculate and allocate rewards based on deposit amount
        uint256 rewardAmount = (amount * REWARD_RATE) / 100;
        rewards[user] += rewardAmount;

        // Emit event for tracking deposits
        emit Deposit(user, amount, shares);
    }
}
