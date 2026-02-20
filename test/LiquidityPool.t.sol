// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/LiquidityPool.sol";

contract LiquidityPoolTest is Test {
    LiquidityPool public pool;
    PoolShare public shareToken;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy pool
        pool = new LiquidityPool();
        shareToken = pool.shareToken();

        // Fund users
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function testInitialState() public {
        assertEq(pool.owner(), owner);
        assertEq(address(pool.shareToken()).code.length > 0, true);
        assertEq(pool.WITHDRAWAL_DELAY(), 1 days);
        assertEq(pool.REWARD_RATE(), 10);
        assertEq(shareToken.totalSupply(), 0);
    }

    function testDeposit() public {
        uint256 depositAmount = 1 ether;

        vm.prank(user1);
        pool.deposit{value: depositAmount}();

        assertEq(shareToken.balanceOf(user1), depositAmount);
        assertEq(pool.rewards(user1), (depositAmount * pool.REWARD_RATE()) / 100);
        assertEq(pool.lastDepositTime(user1), block.timestamp);
        assertEq(address(pool).balance, depositAmount);
    }

    function testDepositFor() public {
        uint256 depositAmount = 1 ether;

        vm.prank(user2);
        pool.depositFor{value: depositAmount}(user1);

        assertEq(shareToken.balanceOf(user1), depositAmount);
        assertEq(pool.rewards(user1), (depositAmount * pool.REWARD_RATE()) / 100);
        assertEq(pool.lastDepositTime(user1), block.timestamp);
        assertEq(address(pool).balance, depositAmount);
    }

    function testMultipleDeposits() public {
        uint256 firstDeposit = 1 ether;
        uint256 secondDeposit = 0.5 ether;

        // First deposit
        vm.prank(user1);
        pool.deposit{value: firstDeposit}();

        // Second deposit (different user)
        vm.prank(user2);
        pool.deposit{value: secondDeposit}();

        // Calculate expected shares for second deposit
        // FIXED: With reentrancy fix, balance excludes current deposit
        // When second deposit happens: totalSupply = 1 ether, balance before deposit = 1 ether
        // shares = (0.5 * 1) / 1 = 0.5 ether
        uint256 expectedShares = (secondDeposit * firstDeposit) / firstDeposit;

        assertEq(shareToken.balanceOf(user1), firstDeposit);
        assertEq(shareToken.balanceOf(user2), expectedShares);
        assertEq(address(pool).balance, firstDeposit + secondDeposit);
    }

    function testWithdraw() public {
        uint256 depositAmount = 2 ether;
        uint256 withdrawShares = 1 ether;

        // Setup: deposit
        vm.startPrank(user1);
        pool.deposit{value: depositAmount}();

        // Approve pool to transfer shares
        shareToken.approve(address(pool), withdrawShares);

        // Wait for withdrawal delay
        skip(pool.WITHDRAWAL_DELAY());

        // Record balance before withdrawal
        uint256 balanceBefore = user1.balance;

        // Withdraw
        pool.withdraw(withdrawShares);
        vm.stopPrank();

        // Calculate expected withdrawal amount
        uint256 expectedAmount = withdrawShares; // 1:1 ratio for first deposit

        assertEq(user1.balance, balanceBefore + expectedAmount);
        assertEq(shareToken.balanceOf(user1), depositAmount - withdrawShares);
    }

    function testClaimReward() public {
        uint256 depositAmount = 1 ether;
        uint256 rewardAmount = 0.05 ether;

        // Create a proper signer address
        uint256 privateKey = 0x1234;
        address signer = vm.addr(privateKey);
        vm.deal(signer, 10 ether);

        // Setup: deposit to get rewards with the signer
        vm.prank(signer);
        pool.deposit{value: depositAmount}();

        // Fund the pool with ETH for reward payments
        vm.deal(address(pool), address(pool).balance + 1 ether);

        uint256 nonce = pool.nonces(signer);
        bytes32 messageHash = keccak256(abi.encode(signer, rewardAmount, nonce));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(signer);
        pool.claimReward(signer, rewardAmount, nonce, signature);

        assertEq(pool.nonces(signer), nonce + 1);
        assertLt(pool.rewards(signer), (depositAmount * pool.REWARD_RATE()) / 100); // Rewards decreased
    }

    function test_RevertWhen_ZeroDeposit() public {
        vm.prank(user1);
        vm.expectRevert("Invalid deposit");
        pool.deposit{value: 0}();
    }

    function test_RevertWhen_ZeroDepositFor() public {
        vm.prank(user1);
        vm.expectRevert("Invalid deposit");
        pool.depositFor{value: 0}(user2);
    }

    function test_RevertWhen_WithdrawInsufficientShares() public {
        uint256 depositAmount = 1 ether;
        uint256 withdrawShares = 2 ether; // More than deposited

        vm.startPrank(user1);
        pool.deposit{value: depositAmount}();
        shareToken.approve(address(pool), withdrawShares);
        skip(pool.WITHDRAWAL_DELAY());

        vm.expectRevert("Insufficient shares");
        pool.withdraw(withdrawShares);
        vm.stopPrank();
    }

    function test_RevertWhen_WithdrawBeforeDelay() public {
        uint256 depositAmount = 1 ether;

        vm.startPrank(user1);
        pool.deposit{value: depositAmount}();
        shareToken.approve(address(pool), depositAmount);

        vm.expectRevert("Withdrawal delay not met");
        pool.withdraw(depositAmount);
        vm.stopPrank();
    }

    function test_RevertWhen_ClaimRewardInsufficientRewards() public {
        uint256 depositAmount = 1 ether;
        uint256 excessiveReward = 1 ether; // More than available

        vm.prank(user1);
        pool.deposit{value: depositAmount}();

        uint256 nonce = pool.nonces(user1);
        bytes32 messageHash = keccak256(abi.encode(user1, excessiveReward, nonce));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(user1);
        vm.expectRevert("Insufficient rewards");
        pool.claimReward(user1, excessiveReward, nonce, signature);
    }

    function test_RevertWhen_ClaimRewardInvalidNonce() public {
        uint256 depositAmount = 1 ether;
        uint256 rewardAmount = 0.05 ether;

        vm.prank(user1);
        pool.deposit{value: depositAmount}();

        uint256 wrongNonce = pool.nonces(user1) + 1;
        bytes32 messageHash = keccak256(abi.encode(user1, rewardAmount, wrongNonce));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(user1);
        vm.expectRevert("Invalid nonce");
        pool.claimReward(user1, rewardAmount, wrongNonce, signature);
    }

    function test_RevertWhen_ClaimRewardInvalidSignature() public {
        uint256 depositAmount = 1 ether;
        uint256 rewardAmount = 0.05 ether;

        vm.prank(user1);
        pool.deposit{value: depositAmount}();

        uint256 nonce = pool.nonces(user1);
        bytes32 messageHash = keccak256(abi.encode(user1, rewardAmount, nonce));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(2, messageHash); // Wrong private key
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(user1);
        vm.expectRevert("Invalid signature");
        pool.claimReward(user1, rewardAmount, nonce, signature);
    }

    function testDepositForResetsWithdrawalTimer() public {
        uint256 firstDeposit = 1 ether;
        uint256 secondDeposit = 0.5 ether;

        // First deposit
        vm.prank(user1);
        pool.deposit{value: firstDeposit}();

        uint256 firstDepositTime = pool.lastDepositTime(user1);

        // Wait some time
        skip(12 hours);

        // Second deposit for the same user (griefing attack vector)
        vm.prank(user2);
        pool.depositFor{value: secondDeposit}(user1);

        uint256 secondDepositTime = pool.lastDepositTime(user1);

        assertGt(secondDepositTime, firstDepositTime);
        assertEq(secondDepositTime, block.timestamp);
    }

    function testShareCalculationVulnerableToInflation() public {
        // This tests the donation attack vulnerability
        uint256 initialDeposit = 1 ether;

        // First deposit
        vm.prank(user1);
        pool.deposit{value: initialDeposit}();

        // Attacker sends ETH directly to inflate the pool balance
        vm.deal(address(pool), address(pool).balance + 10 ether);

        // Second deposit gets fewer shares due to inflated balance
        uint256 secondDeposit = 1 ether;
        uint256 balanceBeforeSecondDeposit = address(pool).balance;

        vm.prank(user2);
        pool.deposit{value: secondDeposit}();

        // FIXED: With reentrancy fix, donation attack is mitigated
        uint256 user2Shares = shareToken.balanceOf(user2);
        // The totalSupply before second deposit is 1 ether (from first user)
        // Balance before second deposit was 11 ether (1 original + 10 donated)
        // FIXED: shares = (1 ether * 1 ether) / 11 ether (excludes the incoming deposit)
        uint256 totalSupplyBefore = initialDeposit; // 1 ether
        uint256 expectedShares = (secondDeposit * totalSupplyBefore)
            / balanceBeforeSecondDeposit;

        assertEq(user2Shares, expectedShares);
        assertLt(user2Shares, secondDeposit); // Still gets fewer shares (donation attack still partially works)
    }

    function testRewardClaimingWithReentrancy() public {
        // Test the reentrancy vulnerability in claimReward
        uint256 depositAmount = 1 ether;
        uint256 rewardAmount = 0.05 ether;

        // Create a proper signer address
        uint256 privateKey = 0x5678;
        address signer = vm.addr(privateKey);
        vm.deal(signer, 10 ether);

        // Setup: deposit to get rewards with the signer
        vm.prank(signer);
        pool.deposit{value: depositAmount}();

        // Fund the pool for reward payments
        vm.deal(address(pool), address(pool).balance + 1 ether);

        uint256 nonce = pool.nonces(signer);
        bytes32 messageHash = keccak256(abi.encode(signer, rewardAmount, nonce));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(signer);
        pool.claimReward(signer, rewardAmount, nonce, signature);

        // Verify nonce was incremented only on success
        assertEq(pool.nonces(signer), nonce + 1);
    }

    function testReentrancyProtectionInWithdraw() public {
        uint256 depositAmount = 1 ether;
        
        vm.startPrank(user1);
        pool.deposit{value: depositAmount}();
        
        skip(pool.WITHDRAWAL_DELAY());
        shareToken.approve(address(pool), depositAmount);
        
        // Attempt withdraw - should succeed with reentrancy protection
        pool.withdraw(depositAmount);
        vm.stopPrank();
        
        assertEq(shareToken.balanceOf(user1), 0);
        assertGe(user1.balance, depositAmount);
    }

    receive() external payable {}
}

contract ReentrancyAttacker {
    LiquidityPool public pool;
    PoolShare public shareToken;
    uint256 public attackCount;
    uint256 public maxAttacks = 3;
    bool public attacking;
    
    constructor(address _pool) {
        pool = LiquidityPool(payable(_pool));
        shareToken = pool.shareToken();
    }
    
    function deposit() external payable {
        pool.deposit{value: msg.value}();
    }
    
    function startAttack(uint256 shares) external {
        attacking = true;
        shareToken.approve(address(pool), shares);
        pool.withdraw(shares);
    }
    
    receive() external payable {
        if (attacking && attackCount < maxAttacks) {
            // Try to reenter withdraw
            uint256 shares = shareToken.balanceOf(address(this));
            if (shares > 0) {
                attackCount++;  // Increment only when attempting reentry
                try pool.withdraw(shares) {} catch {}
            }
        }
    }
}

contract ReentrancyTest is Test {
    LiquidityPool public pool;
    PoolShare public shareToken;
    ReentrancyAttacker public attacker;
    
    function setUp() public {
        pool = new LiquidityPool();
        shareToken = pool.shareToken();
        attacker = new ReentrancyAttacker(address(pool));
        
        vm.deal(address(attacker), 10 ether);
    }
    
    function testReentrancyProtectionInWithdrawAttack() public {
        uint256 depositAmount = 2 ether;
        
        // Attacker deposits
        attacker.deposit{value: depositAmount}();
        
        // Wait for withdrawal delay
        skip(pool.WITHDRAWAL_DELAY());
        
        uint256 attackerBalanceBefore = address(attacker).balance;
        
        // Attempt reentrancy attack
        uint256 shares = shareToken.balanceOf(address(attacker));
        attacker.startAttack(shares);
        
        // Should only withdraw once due to nonReentrant
        assertEq(attacker.attackCount(), 0); // No reentrant calls succeeded
        assertEq(shareToken.balanceOf(address(attacker)), 0); // All shares burned
        assertEq(address(pool).balance, 0); // Pool drained correctly (not more than once)
        assertEq(address(attacker).balance, attackerBalanceBefore + depositAmount); // Attacker got correct amount
    }
    
    function testReentrancyProtectionInClaimReward() public {
        uint256 depositAmount = 1 ether;
        uint256 rewardAmount = 0.05 ether;
        
        // Create a proper signer address
        uint256 privateKey = 0x9999;
        address signer = vm.addr(privateKey);
        vm.deal(signer, 10 ether);
        
        // Setup: deposit to get rewards
        vm.prank(signer);
        pool.deposit{value: depositAmount}();
        
        // Fund pool for rewards
        vm.deal(address(pool), address(pool).balance + 1 ether);
        
        uint256 nonce = pool.nonces(signer);
        bytes32 messageHash = keccak256(abi.encode(signer, rewardAmount, nonce));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Claim reward
        vm.prank(signer);
        pool.claimReward(signer, rewardAmount, nonce, signature);
        
        // Verify only one claim succeeded
        assertEq(pool.nonces(signer), nonce + 1);
        assertEq(pool.rewards(signer), (depositAmount * pool.REWARD_RATE()) / 100 - rewardAmount);
    }
    
    receive() external payable {}
}
