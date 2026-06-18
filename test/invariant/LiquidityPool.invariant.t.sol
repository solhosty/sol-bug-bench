// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/LiquidityPool.sol";

/// @dev Records the share balance it holds at the moment ETH is received, to
///      prove the pool transfers ETH before burning shares (LP-F1).
contract ReentrancyProbe {
    LiquidityPool public pool;
    PoolShare public shareToken;
    uint256 public sharesHeldDuringCallback;

    constructor(LiquidityPool pool_) {
        pool = pool_;
        shareToken = pool_.shareToken();
    }

    function deposit() external payable {
        pool.deposit{value: msg.value}();
    }

    function withdrawAll(uint256 shares) external {
        shareToken.approve(address(pool), shares);
        pool.withdraw(shares);
    }

    receive() external payable {
        sharesHeldDuringCallback = shareToken.balanceOf(address(this));
    }
}

/// @notice Executable proofs for the LiquidityPool invariants in INVARIANTS.md.
///         Every invariant in this section is expected to be VIOLATED on the
///         current code; each test demonstrates the concrete violation.
contract LiquidityPoolInvariantTest is Test {
    LiquidityPool public pool;
    PoolShare public shareToken;

    uint256 internal constant USER_PK = 0xA11CE;
    address internal user;
    address internal attacker = address(0xBEEF);
    address internal funder = address(0xF00D);

    function setUp() public {
        // This contract deploys the pool, so it is `owner()` and receives fees.
        pool = new LiquidityPool();
        shareToken = pool.shareToken();
        user = vm.addr(USER_PK);
    }

    receive() external payable {}

    /// LP-G1: pool ETH must back outstanding shares. Reward claims pay out of
    /// the same ETH that backs shares, so the pool becomes insolvent.
    function test_LP_G1_insolventAfterRewardClaim() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        pool.deposit{value: 10 ether}();

        // First deposit mints 1:1, so balance == totalSupply here.
        assertEq(address(pool).balance, shareToken.totalSupply());

        uint256 amount = pool.rewards(user); // 10% of deposit = 1 ether
        _claimReward(user, USER_PK, amount, user);

        // Pool paid out reward ETH without burning any shares.
        assertLt(address(pool).balance, shareToken.totalSupply());
    }

    /// LP-F1: shares must be burned before ETH leaves the contract.
    /// The probe still holds its full share balance while it receives ETH.
    function test_LP_F1_ethSentBeforeSharesBurned() public {
        ReentrancyProbe probe = new ReentrancyProbe(pool);
        vm.deal(address(probe), 5 ether);
        probe.deposit{value: 5 ether}();

        vm.warp(block.timestamp + pool.WITHDRAWAL_DELAY() + 1);
        probe.withdrawAll(5 ether);

        // CEI violation: shares not yet burned when the ETH callback ran.
        assertEq(probe.sharesHeldDuringCallback(), 5 ether);
    }

    /// LP-F3: reward ETH for `user` must only ever reach `user`. The payout
    /// goes to `msg.sender`, so anyone with a valid signature steals it.
    function test_LP_F3_rewardRedirectedToCaller() public {
        vm.deal(user, 10 ether);
        vm.prank(user);
        pool.deposit{value: 10 ether}();

        uint256 amount = pool.rewards(user); // 1 ether
        uint256 attackerBefore = attacker.balance;

        _claimReward(user, USER_PK, amount, attacker);

        // Attacker pocketed the user's reward minus the protocol fee.
        assertEq(attacker.balance, attackerBefore + (amount - amount / 10));
    }

    /// LP-F4: every share-minting deposit must arm the withdrawal delay.
    /// `depositFor` leaves `lastDepositTime` at zero, so the receiver can
    /// withdraw immediately, bypassing WITHDRAWAL_DELAY.
    function test_LP_F4_depositForBypassesWithdrawalDelay() public {
        vm.warp(block.timestamp + 2 days);

        vm.deal(funder, 5 ether);
        vm.prank(funder);
        pool.depositFor{value: 5 ether}(user);

        assertEq(pool.lastDepositTime(user), 0);

        vm.startPrank(user);
        shareToken.approve(address(pool), 5 ether);
        pool.withdraw(5 ether); // succeeds with no enforced delay for `user`
        vm.stopPrank();

        assertEq(user.balance, 5 ether);
    }

    function _claimReward(
        address rewardUser,
        uint256 pk,
        uint256 amount,
        address caller
    ) internal {
        uint256 nonce = pool.nonces(rewardUser);
        bytes32 messageHash = keccak256(abi.encode(rewardUser, amount, nonce));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(caller);
        pool.claimReward(rewardUser, amount, nonce, signature);
    }
}
