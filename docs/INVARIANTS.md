# Protocol Invariants — DeFiHub (sol-bug-bench)

System invariants for the DeFiHub contracts. Each invariant is a property that
MUST hold for every reachable state and transition of the protocol. They are
written to be **falsifiable**: a single concrete state or call sequence that
violates the statement is a bug.

- **Scope:** `src/GovernanceToken.sol`, `src/LiquidityPool.sol`, `src/StableCoin.sol`
- **Convention:** `[GLOBAL-*]` hold across all states; `[FN-*]` constrain a
  specific function's pre/post-state.
- **Status legend:** ✅ expected to hold · ❌ expected to break · ⚠️ likely
  violated (subtle)

Each invariant is independent and single-property — assert them one at a time
in a Foundry/Echidna handler.

---

## 1. LiquidityPool / PoolShare

| ID    | Type                 | Invariant                                                                                                                                 | Status |
| ----- | -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| LP-G1 | GLOBAL               | `address(this).balance` is always ≥ the ETH redeemable by burning the entire `shareToken.totalSupply()` at the current share price.       | ❌     |
| LP-G2 | GLOBAL               | The sum of all unclaimed `rewards[user]` is fully covered by ETH that is _not_ required to back outstanding shares.                       | ❌     |
| LP-F1 | FN `withdraw`        | A caller's `shareToken.balanceOf(msg.sender)` is reduced by `shares` (burn) **before** any ETH is transferred out.                        | ❌     |
| LP-F2 | FN `claimReward`     | If the protocol fee transfer succeeds, `rewards[user]` decreases by exactly `amount` and `nonces[user]` increments by 1 in the same call. | ❌     |
| LP-F3 | FN `claimReward`     | Reward ETH for `user` is only ever credited to `user`, never to an arbitrary `msg.sender`.                                                | ❌     |
| LP-F4 | FN `depositFor`      | Any deposit that mints shares for a user updates that user's `lastDepositTime`, so the `WITHDRAWAL_DELAY` applies on every deposit path.  | ❌     |
| LP-F5 | FN `_processDeposit` | When `shareToken.totalSupply() == 0`, the shares minted equal the ETH deposited (1:1 bootstrap ratio).                                    | ✅     |
| LP-F6 | FN `withdraw`        | Withdrawal reverts unless `block.timestamp ≥ lastDepositTime[msg.sender] + WITHDRAWAL_DELAY`.                                             | ⚠️     |

### Notes

- **LP-G1 / LP-G2:** `claimReward` and `_processDeposit` pay rewards out of the
  same ETH that backs `PoolShare`. Reward outflow is unbacked → share holders
  cannot all redeem.
- **LP-F1:** ETH is sent via `msg.sender.call{value: amount}` _before_
  `transferFrom` + `burn`. Classic checks-effects-interactions violation →
  reentrancy drains the pool.
- **LP-F2:** On a failed user transfer the fee has already left the contract but
  `rewards`/`nonces` are never decremented — value leaks and the claim can be
  retried.
- **LP-F3:** The signature proves `user` authorized the claim, but the payout
  goes to `msg.sender`. Anyone holding a valid signature steals the reward.

---

## 2. GovernanceToken / GroupStaking

| ID    | Type                   | Invariant                                                                                                                                 | Status |
| ----- | ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| GT-G1 | GLOBAL                 | `totalSupply()` only ever increases through a call made by an authorized minter.                                                          | ❌     |
| GT-G2 | GLOBAL                 | A user's `blacklisted` status is only mutated by a privileged admin.                                                                      | ❌     |
| GS-G1 | GLOBAL                 | For every existing group, `totalAmount` equals cumulative `stakeToGroup` amounts minus cumulative tokens actually transferred to members. | ⚠️     |
| GS-G2 | GLOBAL                 | For every existing group, the stored `weights` sum to exactly 100.                                                                        | ✅     |
| GS-F1 | FN `withdrawFromGroup` | A withdrawal cannot be permanently blocked by the state (e.g. blacklist) of a single group member.                                        | ❌     |
| GS-F2 | FN `withdrawFromGroup` | Only `group.owner` can withdraw, and `totalAmount` decreases by exactly `amount`.                                                         | ⚠️     |

### Notes

- **GT-G1:** `mint(address,uint256)` has no access control — anyone can inflate
  supply arbitrarily.
- **GT-G2:** `updateUserStatus` is permissionless — any address can blacklist
  any other address (griefing / DoS on transfers).
- **GS-G1 / GS-F2:** `withdrawFromGroup` subtracts the full `amount` from
  `totalAmount` but distributes `amount * weight / 100` per member; integer
  truncation strands dust in the contract while accounting assumes it left.
- **GS-F1:** A single blacklisted member makes `token.transfer` revert, reverting
  the entire distribution and freezing all group funds.

---

## 3. StableCoin / TokenStreamer

| ID    | Type                    | Invariant                                                                                                     | Status |
| ----- | ----------------------- | ------------------------------------------------------------------------------------------------------------- | ------ |
| SC-G1 | GLOBAL                  | StableCoin `totalSupply()` only increases through a call made by an authorized minter.                        | ❌     |
| SC-G2 | GLOBAL                  | One whole USDS unit equals `10 ** decimals()` base units consistently across all integrations.                | ⚠️     |
| TS-G1 | GLOBAL                  | `stablecoin.balanceOf(streamer)` is always ≥ the sum of `totalDeposited − totalWithdrawn` over all streams.   | ❌     |
| TS-G2 | GLOBAL                  | For every stream, `totalWithdrawn ≤ totalDeposited`.                                                          | ✅     |
| TS-F1 | FN `addToStream`        | Tokens added to an active stream vest only over the _remaining_ duration, never against time already elapsed. | ❌     |
| TS-F2 | FN `withdrawFromStream` | Cumulative withdrawals never exceed the linearly-vested amount at `block.timestamp`.                          | ⚠️     |

### Notes

- **SC-G1:** `StableCoin.mint` is permissionless — unbacked supply inflation.
- **SC-G2:** `decimals()` returns `1`, so "1 USDS" is 10 base units. Any
  integration assuming 18 decimals mis-scales balances by 10^17.
- **TS-G1 / TS-F1:** `getAvailableTokens` computes
  `vested = totalDeposited * elapsed / duration` against the _full_ deposited
  total. Calling `addToStream` after time has elapsed retroactively vests the
  new funds against already-elapsed time → recipient can withdraw more than the
  schedule should allow, eventually exceeding the contract's balance.

---

## How to use

These map 1:1 to handler assertions for a stateful fuzzing campaign:

```solidity
// Foundry invariant test — one assertion per ID
function invariant_LP_G1_poolSolvency() public {
    uint256 supply = shareToken.totalSupply();
    if (supply == 0) return;
    // redeemable value of all shares must be backed by ETH on hand
    assertGe(address(pool).balance, supply * sharePrice() / 1e18);
}
```

For the Cygent Knowledge tab, each row maps to an invariant entry as
`{ target, property, expectation }` — `target` = the `Contract.function` in the
Type column, `property` = the Invariant text, `expectation` = the Status note.
