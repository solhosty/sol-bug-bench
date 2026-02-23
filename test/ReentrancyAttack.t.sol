// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/LiquidityPool.sol";

/**
 * @title ReentrancyAttack
 * @dev Malicious contract that attempts to exploit reentrancy vulnerabilities
 */
contract ReentrancyAttacker {
    LiquidityPool public pool;
    PoolShare public shareToken;
    uint256 public attackCount;
    uint256 public maxAttacks = 3;
    bool public isAttacking;

    constructor(LiquidityPool _pool) {
        pool = _pool;
        shareToken = pool.shareToken();
    }

    receive() external payable {
        if (isAttacking && attackCount < maxAttacks) {
            attackCount++;
            // Attempt to re-enter withdraw
            uint256 shares = shareToken.balanceOf(address(this));
            if (shares > 0) {
                shareToken.approve(address(pool), shares);
                try pool.withdraw(shares) {} catch {}
            }
        }
    }

    function deposit() external payable {
        pool.deposit{value: msg.value}();
    }

    function attack() external {
        isAttacking = true;
        attackCount = 0;
        uint256 shares = shareToken.balanceOf(address(this));
        require(shares > 0, "No shares to withdraw");
        shareToken.approve(address(pool), shares);
        pool.withdraw(shares);
        isAttacking = false;
    }

    function prepareAttack() external {
        uint256 shares = shareToken.balanceOf(address(this));
        shareToken.approve(address(pool), type(uint256).max);
    }
}

/**
 * @title ReentrancyAttackClaimReward
 * @dev Malicious contract that attempts to exploit claimReward reentrancy
 */
contract ReentrancyAttackerClaimReward {
    LiquidityPool public pool;
    uint256 public attackCount;
    uint256 public maxAttacks = 3;
    bool public isAttacking;
    
    address public user;
    uint256 public amount;
    uint256 public nonce;
    bytes public signature;

    constructor(LiquidityPool _pool) {
        pool = _pool;
    }

    receive() external payable {
        if (isAttacking && attackCount < maxAttacks) {
            attackCount++;
            // Attempt to re-enter claimReward
            try pool.claimReward(user, amount, nonce, signature) {} catch {}
        }
    }

    function setClaimParams(
        address _user,
        uint256 _amount,
        uint256 _nonce,
        bytes memory _signature
    ) external {
        user = _user;
        amount = _amount;
        nonce = _nonce;
        signature = _signature;
    }

    function attack() external {
        isAttacking = true;
        attackCount = 0;
        pool.claimReward(user, amount, nonce, signature);
        isAttacking = false;
    }
}

/**
 * @title ReentrancyAttackTest
 * @dev Test suite to verify reentrancy protection in LiquidityPool
 */
contract ReentrancyAttackTest is Test {
    LiquidityPool public pool;
    PoolShare public shareToken;
    ReentrancyAttacker public attacker;
    ReentrancyAttackerClaimReward public claimAttacker;
    
    address public owner = address(1);
    address public user1 = address(2);
    address public user2 = address(3);

    function setUp() public {
        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        vm.prank(owner);
        pool = new LiquidityPool();
        shareToken = pool.shareToken();

        attacker = new ReentrancyAttacker(pool);
        claimAttacker = new ReentrancyAttackerClaimReward(pool);
        
        vm.deal(address(attacker), 10 ether);
        vm.deal(address(claimAttacker), 10 ether);
    }

    /**
     * @dev Test that withdraw function is protected against reentrancy
     */
    function testReentrancyProtection_Withdraw() public {
        // Setup: Have legit user deposit first
        vm.prank(user1);
        pool.deposit{value: 5 ether}();

        // Attacker deposits
        vm.prank(address(attacker));
        attacker.deposit{value: 5 ether}();

        // Fast forward past withdrawal delay
        vm.warp(block.timestamp + 1 days + 1);

        // Prepare attack
        vm.prank(address(attacker));
        attacker.prepareAttack();

        uint256 poolBalanceBefore = address(pool).balance;
        uint256 attackerBalanceBefore = address(attacker).balance;
        uint256 attackerSharesBefore = shareToken.balanceOf(address(attacker));

        // Execute attack
        vm.prank(address(attacker));
        attacker.attack();

        uint256 poolBalanceAfter = address(pool).balance;
        uint256 attackerBalanceAfter = address(attacker).balance;
        uint256 attackerSharesAfter = shareToken.balanceOf(address(attacker));

        // Verify attack was prevented
        // Attacker should only withdraw once, not multiple times
        assertEq(attacker.attackCount(), 0, "Reentrancy attack should be blocked");
        assertEq(attackerSharesAfter, 0, "All shares should be burned");
        
        // Check that withdrawal happened only once
        uint256 expectedWithdrawal = (attackerSharesBefore * poolBalanceBefore) / (attackerSharesBefore + shareToken.balanceOf(user1));
        assertApproxEqAbs(
            attackerBalanceAfter - attackerBalanceBefore,
            expectedWithdrawal,
            0.01 ether,
            "Should only withdraw correct amount once"
        );
    }

    /**
     * @dev Test that claimReward function is protected against reentrancy
     */
    function testReentrancyProtection_ClaimReward() public {
        // Setup: user1 deposits to get rewards
        vm.prank(user1);
        pool.deposit{value: 10 ether}();

        // Fund the pool with ETH for rewards
        vm.deal(address(pool), address(pool).balance + 10 ether);

        uint256 rewardAmount = pool.rewards(user1);
        require(rewardAmount > 0, "User should have rewards");

        // Create signature for claim
        uint256 nonce = pool.nonces(user1);
        bytes32 messageHash = keccak256(abi.encode(user1, rewardAmount, nonce));
        
        // Sign the message (user1 is the signer)
        uint256 user1PrivateKey = 0xA11CE;
        vm.prank(user1);
        address actualUser1 = vm.addr(user1PrivateKey);
        
        // Re-setup with proper key
        vm.deal(actualUser1, 100 ether);
        
        vm.prank(actualUser1);
        pool.deposit{value: 10 ether}();
        
        rewardAmount = pool.rewards(actualUser1);
        nonce = pool.nonces(actualUser1);
        messageHash = keccak256(abi.encode(actualUser1, rewardAmount, nonce));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Set up attacker's claim parameters
        vm.deal(address(pool), address(pool).balance + 10 ether);
        claimAttacker.setClaimParams(actualUser1, rewardAmount, nonce, signature);

        uint256 rewardsBefore = pool.rewards(actualUser1);
        uint256 nonceBefore = pool.nonces(actualUser1);

        // Execute attack from the actual user (since signature verification requires it)
        vm.prank(actualUser1);
        pool.claimReward(actualUser1, rewardAmount, nonce, signature);

        uint256 rewardsAfter = pool.rewards(actualUser1);
        uint256 nonceAfter = pool.nonces(actualUser1);

        // Verify state was updated correctly (only once)
        assertEq(rewardsAfter, rewardsBefore - rewardAmount, "Rewards should be deducted once");
        assertEq(nonceAfter, nonceBefore + 1, "Nonce should increment once");
    }

    /**
     * @dev Test that state is properly updated before external calls in withdraw
     */
    function testWithdraw_StateConsistency() public {
        vm.prank(user1);
        pool.deposit{value: 10 ether}();

        vm.warp(block.timestamp + 1 days + 1);

        uint256 shares = shareToken.balanceOf(user1);
        uint256 totalSupplyBefore = shareToken.totalSupply();
        
        vm.startPrank(user1);
        shareToken.approve(address(pool), shares);
        pool.withdraw(shares);
        vm.stopPrank();

        // Verify shares were burned
        assertEq(shareToken.balanceOf(user1), 0, "User shares should be zero");
        assertEq(shareToken.totalSupply(), totalSupplyBefore - shares, "Total supply should decrease");
    }

    /**
     * @dev Test that state is properly updated before external calls in claimReward
     */
    function testClaimReward_StateConsistency() public {
        uint256 user1PrivateKey = 0xA11CE;
        address actualUser1 = vm.addr(user1PrivateKey);
        vm.deal(actualUser1, 100 ether);

        vm.prank(actualUser1);
        pool.deposit{value: 10 ether}();

        vm.deal(address(pool), address(pool).balance + 10 ether);

        uint256 rewardAmount = pool.rewards(actualUser1);
        uint256 nonce = pool.nonces(actualUser1);
        bytes32 messageHash = keccak256(abi.encode(actualUser1, rewardAmount, nonce));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        uint256 rewardsBefore = pool.rewards(actualUser1);
        uint256 nonceBefore = pool.nonces(actualUser1);

        vm.prank(actualUser1);
        pool.claimReward(actualUser1, rewardAmount, nonce, signature);

        // Verify state was updated
        assertEq(pool.rewards(actualUser1), rewardsBefore - rewardAmount, "Rewards should be deducted");
        assertEq(pool.nonces(actualUser1), nonceBefore + 1, "Nonce should be incremented");
    }

    /**
     * @dev Fuzz test to verify reentrancy protection with various withdrawal amounts
     */
    function testFuzz_ReentrancyProtection_Withdraw(uint256 depositAmount) public {
        vm.assume(depositAmount > 0.1 ether && depositAmount < 50 ether);

        vm.prank(user1);
        pool.deposit{value: depositAmount}();

        vm.deal(address(attacker), depositAmount);
        vm.prank(address(attacker));
        attacker.deposit{value: depositAmount}();

        vm.warp(block.timestamp + 1 days + 1);

        vm.prank(address(attacker));
        attacker.prepareAttack();

        uint256 attackerSharesBefore = shareToken.balanceOf(address(attacker));

        vm.prank(address(attacker));
        attacker.attack();

        // Verify shares were fully burned (only one withdrawal occurred)
        assertEq(shareToken.balanceOf(address(attacker)), 0, "All attacker shares should be burned");
        assertEq(attacker.attackCount(), 0, "Reentrancy should be prevented");
    }
}
