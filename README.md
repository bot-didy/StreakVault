# StreakVault

StreakVault is a Stacks smart contract that distributes STX rewards to users who maintain a consistent streak of periodic check-ins. It demonstrates time-based state management, on-chain streak tracking, and admin-governed configuration using Clarity 3.

## Overview

- **Entry point**: `streakVault/contracts/streakVault.clar`
- **Goal**: Encourage recurring engagement by granting rewards to users who meet a minimum streak requirement.
- **Design highlights**:
  - Pure on-chain streak bookkeeping through Clarity data maps.
  - Configurable cadence (block periods), minimum streak, and reward size.
  - Safe-guards against double claims and insufficient reward funds.

## Core Functions

| Function | Access | Description |
|----------|--------|-------------|
| `check-in` | Public | Records a user activity if enough blocks have passed since the last check-in, then increments their streak. |
| `claim` | Public | Pays out `reward-per-claim` to users who meet the streak requirement and have not already claimed in the current period. |
| `set-config` | Admin only | Updates `period-length`, `min-streak-to-claim`, and `reward-per-claim`. |
| `transfer-admin` | Admin only | Hands admin rights to another principal. |
| `get-config` | Read-only | Returns the current configuration. |
| `get-user` | Read-only | Returns the caller’s last check-in height and streak count. |
| `current-period` | Read-only | Derives a deterministic period ID from `stacks-block-height`. |

### Data Structures

- `last-checkin`: maps each user to the last block height where a successful check-in occurred.
- `user-streak`: stores each user’s current streak count.
- `has-claimed`: marks whether a user has already claimed rewards for a specific period.
- `admin`, `period-length`, `min-streak-to-claim`, `reward-per-claim`: contract-wide configuration stored in data variables.

## Requirements

- Clarity 3 toolchain (Clarinet 1.6+ or compatible).
- Fund the contract with sufficient STX before calling `claim`; otherwise `ERR-NO-FUNDS` is returned.
- Admin transactions are restricted to the stored admin principal (`tx-sender` upon deployment by default).

## Usage

Run static analysis:

```sh
clarinet check
```

Open an interactive REPL for manual testing:

```sh
clarinet console
```

Inside the console you can simulate contract calls, e.g.:

```clarity
::contract-call? .streakVault check-in
::contract-call? .streakVault claim
```

## Testing

This repository is compatible with Clarinet’s TypeScript testing harness. To enable contract unit tests:

```sh
npm install
npm test
```

Add custom scenarios under `tests/` to cover streak progression, claim eligibility, admin reconfiguration, and insufficient balance failures.

## Roadmap Ideas

- Validate admin-provided configuration values (e.g., minimum period length, maximum reward).
- Emit events (via `print`) for analytics on check-ins and claims.
- Integrate regression tests for edge cases such as multiple users competing for rewards.

## License

No license has been specified yet. Add a license file before open-sourcing or distributing the project.
