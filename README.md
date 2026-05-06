# DeFiHub Solidity Bug Bench

[![CI](https://github.com/hans-cyfrin/sol-bug-bench/actions/workflows/test.yml/badge.svg)](https://github.com/hans-cyfrin/sol-bug-bench/actions/workflows/test.yml)

DeFiHub is a decentralized finance protocol that combines governance, liquidity
provision, and token streaming in a single Solidity codebase. This repository is
also intentionally used as a smart contract security benchmark, so selected
vulnerabilities are preserved for testing and education.

> [!WARNING]
> This project includes intentionally vulnerable code paths for security testing.
> Do not deploy these contracts to production or use real funds.

## Protocol Overview

DeFiHub is organized around three protocol pillars: governance participation,
liquidity provision, and structured token distribution. The contracts model a
realistic DeFi architecture while remaining compact enough for auditing,
tool-benchmarking, and training workflows.

## Contracts

| Contract | Description |
| --- | --- |
| `src/GovernanceToken.sol` | Governance token and group staking logic for weighted participation and rewards. |
| `src/LiquidityPool.sol` | ETH liquidity pool and share-token accounting with reward and withdrawal flows. |
| `src/StableCoin.sol` | Stablecoin and token streaming primitives for time-based distribution scenarios. |

Known vulnerabilities are tracked in the
[GitHub Issues](https://github.com/hans-cyfrin/sol-bug-bench/issues) tab using
severity labels.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

## Installation

```bash
git clone --recurse-submodules https://github.com/hans-cyfrin/sol-bug-bench.git
cd sol-bug-bench
forge install
forge build
```

## Testing

```bash
# Run full suite
forge test

# Verbose output
forge test -vvv

# Contract-specific tests
forge test --match-contract GovernanceTokenTest
forge test --match-contract LiquidityPoolTest
forge test --match-contract StableCoinTest
```

## Formatting

```bash
forge fmt
```

## Documentation

- `docs/DeFiHub.md`: full protocol architecture and flow documentation
- `docs/known_issue.md`: example known issue and vulnerable pattern notes

## Issues Tooling

The `issues/` folder includes scripts for pulling vulnerability metadata from
GitHub and exporting it as JSON.

```bash
cd issues
python3 -m pip install -r requirements.txt
python3 fetch_issues.py
```

## Contributing

- Add new vulnerable or fixed benchmark scenarios as focused Solidity contracts
  and tests.
- File GitHub issues for vulnerabilities with severity labels (`Critical`,
  `High`, `Medium`, `Low`) and clear reproduction notes.
- Keep educational context explicit so each benchmark case is easy to analyze.

## License

MIT
