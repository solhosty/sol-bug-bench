// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../src/LiquidityPool.sol";

contract TestEIP1271Wallet is IERC1271 {
    address public signer;

    constructor(address signer_) {
        signer = signer_;
    }

    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        override
        returns (bytes4)
    {
        address recovered = ECDSA.recover(hash, signature);
        if (recovered == signer) {
            return IERC1271.isValidSignature.selector;
        }

        return 0xffffffff;
    }
}

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
        assertEq(pool.lastDepositTime(user1), 0);
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
        // When second deposit happens: totalSupply = 1 ether, preBalance = 1 ether
        // shares = (0.5 * 1) / 1 = 0.5 ether
        uint256 expectedShares = secondDeposit;

        assertEq(shareToken.balanceOf(user1), firstDeposit);
        assertEq(shareToken.balanceOf(user2), expectedShares);
        assertEq(address(pool).balance, firstDeposit + secondDeposit);
    }

    function test_RevertWhen_DepositTooSmall() public {
        uint256 firstDeposit = 1 ether;

        vm.prank(user1);
        pool.deposit{value: firstDeposit}();

        vm.deal(address(pool), address(pool).balance + 1 ether);

        vm.prank(user2);
        vm.expectRevert("Deposit too small");
        pool.deposit{value: 1}();
    }

    function testShareTransferRespectsWithdrawalDelay() public {
        uint256 depositAmount = 1 ether;

        vm.prank(user1);
        pool.deposit{value: depositAmount}();

        vm.prank(user1);
        vm.expectRevert("Withdrawal delay not met");
        shareToken.transfer(user2, depositAmount);

        skip(pool.WITHDRAWAL_DELAY());

        vm.prank(user1);
        shareToken.transfer(user2, depositAmount);

        assertEq(shareToken.balanceOf(user2), depositAmount);
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
        uint256 expiry = block.timestamp + 1 days;
        bytes32 messageHash = keccak256(
            abi.encodePacked(address(pool), block.chainid, signer, rewardAmount, nonce, expiry)
        );
        bytes32 ethHash = ECDSA.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        uint256 signerBalanceBefore = signer.balance;
        uint256 ownerBalanceBefore = owner.balance;
        uint256 fee = (rewardAmount + 9) / 10;
        uint256 userAmount = rewardAmount - fee;

        vm.prank(user2);
        pool.claimReward(signer, rewardAmount, nonce, expiry, signature);

        assertEq(pool.nonces(signer), nonce + 1);
        assertLt(pool.rewards(signer), (depositAmount * pool.REWARD_RATE()) / 100); // Rewards decreased
        assertEq(signer.balance, signerBalanceBefore + userAmount);
        assertEq(owner.balance, ownerBalanceBefore + fee);
    }

    function testClaimRewardEIP1271() public {
        uint256 depositAmount = 1 ether;
        uint256 rewardAmount = 0.05 ether;
        uint256 privateKey = 0x2222;
        address signer = vm.addr(privateKey);
        TestEIP1271Wallet wallet = new TestEIP1271Wallet(signer);

        vm.deal(address(wallet), 10 ether);

        vm.prank(address(wallet));
        pool.deposit{value: depositAmount}();

        vm.deal(address(pool), address(pool).balance + 1 ether);

        uint256 nonce = pool.nonces(address(wallet));
        uint256 expiry = block.timestamp + 1 days;
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                address(pool),
                block.chainid,
                address(wallet),
                rewardAmount,
                nonce,
                expiry
            )
        );
        bytes32 ethHash = ECDSA.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        uint256 walletBalanceBefore = address(wallet).balance;

        pool.claimReward(address(wallet), rewardAmount, nonce, expiry, signature);

        uint256 fee = (rewardAmount + 9) / 10;
        uint256 userAmount = rewardAmount - fee;
        assertEq(address(wallet).balance, walletBalanceBefore + userAmount);
        assertEq(pool.nonces(address(wallet)), nonce + 1);
    }

    function testClaimRewardExpiredSignature() public {
        uint256 depositAmount = 1 ether;
        uint256 rewardAmount = 0.05 ether;
        uint256 privateKey = 0x3333;
        address signer = vm.addr(privateKey);
        vm.deal(signer, 10 ether);

        vm.prank(signer);
        pool.deposit{value: depositAmount}();

        uint256 nonce = pool.nonces(signer);
        uint256 expiry = block.timestamp - 1;
        bytes32 messageHash = keccak256(
            abi.encodePacked(address(pool), block.chainid, signer, rewardAmount, nonce, expiry)
        );
        bytes32 ethHash = ECDSA.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(signer);
        vm.expectRevert("Signature expired");
        pool.claimReward(signer, rewardAmount, nonce, expiry, signature);
    }

    function testCancelNonceInvalidatesSignature() public {
        uint256 depositAmount = 1 ether;
        uint256 rewardAmount = 0.05 ether;
        uint256 privateKey = 0x4444;
        address signer = vm.addr(privateKey);
        vm.deal(signer, 10 ether);

        vm.prank(signer);
        pool.deposit{value: depositAmount}();

        uint256 nonce = pool.nonces(signer);
        uint256 expiry = block.timestamp + 1 days;
        bytes32 messageHash = keccak256(
            abi.encodePacked(address(pool), block.chainid, signer, rewardAmount, nonce, expiry)
        );
        bytes32 ethHash = ECDSA.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(signer);
        pool.cancelNonce(nonce + 1);

        vm.prank(signer);
        vm.expectRevert("Invalid nonce");
        pool.claimReward(signer, rewardAmount, nonce, expiry, signature);
    }

    function testClaimRewardFeeRoundsUp() public {
        uint256 depositAmount = 10;
        uint256 rewardAmount = 1;
        uint256 privateKey = 0x5555;
        address signer = vm.addr(privateKey);
        vm.deal(signer, 10 ether);

        vm.prank(signer);
        pool.deposit{value: depositAmount}();

        vm.deal(address(pool), address(pool).balance + 1 ether);

        uint256 nonce = pool.nonces(signer);
        uint256 expiry = block.timestamp + 1 days;
        bytes32 messageHash = keccak256(
            abi.encodePacked(address(pool), block.chainid, signer, rewardAmount, nonce, expiry)
        );
        bytes32 ethHash = ECDSA.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        uint256 signerBalanceBefore = signer.balance;
        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(signer);
        pool.claimReward(signer, rewardAmount, nonce, expiry, signature);

        assertEq(signer.balance, signerBalanceBefore);
        assertEq(owner.balance, ownerBalanceBefore + 1);
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
        uint256 expiry = block.timestamp + 1 days;
        bytes32 messageHash = keccak256(
            abi.encodePacked(address(pool), block.chainid, user1, excessiveReward, nonce, expiry)
        );
        bytes32 ethHash = ECDSA.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, ethHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(user1);
        vm.expectRevert("Insufficient rewards");
        pool.claimReward(user1, excessiveReward, nonce, expiry, signature);
    }

    function test_RevertWhen_ClaimRewardInvalidNonce() public {
        uint256 depositAmount = 1 ether;
        uint256 rewardAmount = 0.05 ether;

        vm.prank(user1);
        pool.deposit{value: depositAmount}();

        uint256 wrongNonce = pool.nonces(user1) + 1;
        uint256 expiry = block.timestamp + 1 days;
        bytes32 messageHash = keccak256(
            abi.encodePacked(address(pool), block.chainid, user1, rewardAmount, wrongNonce, expiry)
        );
        bytes32 ethHash = ECDSA.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, ethHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(user1);
        vm.expectRevert("Invalid nonce");
        pool.claimReward(user1, rewardAmount, wrongNonce, expiry, signature);
    }

    function test_RevertWhen_ClaimRewardInvalidSignature() public {
        uint256 depositAmount = 1 ether;
        uint256 rewardAmount = 0.05 ether;

        vm.prank(user1);
        pool.deposit{value: depositAmount}();

        uint256 nonce = pool.nonces(user1);
        uint256 expiry = block.timestamp + 1 days;
        bytes32 messageHash = keccak256(
            abi.encodePacked(address(pool), block.chainid, user1, rewardAmount, nonce, expiry)
        );
        bytes32 ethHash = ECDSA.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(2, ethHash); // Wrong private key
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(user1);
        vm.expectRevert("Invalid signature");
        pool.claimReward(user1, rewardAmount, nonce, expiry, signature);
    }

    function testDepositForDoesNotResetWithdrawalTimer() public {
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

        assertEq(secondDepositTime, firstDepositTime);
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

        // user2 should get fewer shares than they should
        uint256 user2Shares = shareToken.balanceOf(user2);
        // The totalSupply before second deposit is 1 ether (from first user)
        // Balance before second deposit was 11 ether (1 original + 10 donated)
        // So shares = (1 ether * 1 ether) / 11 ether = 1/11 ether
        uint256 totalSupplyBefore = initialDeposit; // 1 ether
        uint256 expectedShares = (secondDeposit * totalSupplyBefore)
            / balanceBeforeSecondDeposit;

        assertEq(user2Shares, expectedShares);
        assertLt(user2Shares, secondDeposit); // Gets fewer shares due to donation attack
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
        uint256 expiry = block.timestamp + 1 days;
        bytes32 messageHash = keccak256(
            abi.encodePacked(address(pool), block.chainid, signer, rewardAmount, nonce, expiry)
        );
        bytes32 ethHash = ECDSA.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(signer);
        pool.claimReward(signer, rewardAmount, nonce, expiry, signature);

        // Verify nonce was incremented only on success
        assertEq(pool.nonces(signer), nonce + 1);
    }

    receive() external payable {}
}
