# 13 - Gatekeeper One

## 1. Challenge Overview

- **Objective**: Call `enter(bytes8 _gateKey)` and pass all three modifiers (`gateOne`, `gateTwo`, `gateThree`) so `entrant` becomes `tx.origin`.
- **Vulnerability Category**: Origin Check Bypass (`tx.origin`), Exact Gas Manipulation (`gasleft()`), Integer Downcasting & Bitmasking.

---

## 2. Contract Source Code

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GatekeeperOne {
    address public entrant;

    modifier gateOne() {
        require(msg.sender != tx.origin);
        _;
    }

    modifier gateTwo() {
        require(gasleft() % 8191 == 0);
        _;
    }

    modifier gateThree(bytes8 _gateKey) {
        require(uint32(uint64(_gateKey)) == uint16(uint64(_gateKey)), "GatekeeperOne: invalid gateThree part one");
        require(uint32(uint64(_gateKey)) != uint64(_gateKey), "GatekeeperOne: invalid gateThree part two");
        require(uint32(uint64(_gateKey)) == uint16(uint160(tx.origin)), "GatekeeperOne: invalid gateThree part three");
        _;
    }

    function enter(bytes8 _gateKey) public gateOne gateTwo gateThree(_gateKey) returns (bool) {
        entrant = tx.origin;
        return true;
    }
}
```

---

## 3. Study Notes & Gate Breakdown

### Gate 1: Caller vs. Origin (`msg.sender != tx.origin`)

```solidity
require(msg.sender != tx.origin);
```

- When calling directly from an EOA, `msg.sender == tx.origin`.
- Routing the call through an intermediary contract (`GatekeeperOneAttack`) sets `msg.sender = address(GatekeeperOneAttack)` while keeping `tx.origin = player EOA`, satisfying `msg.sender != tx.origin`.
- **Foundry testing detail**: Single-argument `vm.prank(player)` only overrides `msg.sender`, leaving `tx.origin` as Foundry's default caller (`0x1804...`). Two-argument `vm.prank(player, player)` must be used so `entrant = tx.origin` resolves to `player`.

---

### Gate 2: Exact Gas Alignment (`gasleft() % 8191 == 0`)

```solidity
require(gasleft() % 8191 == 0);
```

- Before execution reaches `gasleft()` (EVM `GAS` opcode) inside `gateTwo`, the EVM executes calldata dispatch, selector matching, and `gateOne`, consuming a fixed `X` gas.
- Sending `(8191 * N) + X` gas ensures that after `X` gas is spent, `gasleft()` equals `8191 * N` (`gasleft() % 8191 == 0`).
- **Why `8191 * 3` instead of `8191 * 1`**: Passing `gateTwo` still leaves `gateThree` checks and an `SSTORE` (`entrant = tx.origin`, cold write ~20,000 gas) to finish execution. `8191 * 3 = 24,573` gives enough remaining gas headroom to complete the transaction without running out of gas after `gateTwo`.
- **Why brute-force in a `for` loop**: The exact pre-`gasleft()` cost `X` depends on the compiler version and optimizer settings used to deploy the target (`X = 265` in our local Solc 0.8.30 test vs. whatever Solc compiled the live Ethernaut instance). Using a low-level `.call{gas: (8191 * 3) + i}(payload)` prevents failed attempts from reverting the outer transaction—we just test `i = 0..8190` until `success == true`.

---

### Type Casting Deep Dive (Solidity `>= 0.8.0`)

Understanding every cast inside `gateThree` and `GatekeeperOneAttack` explains _why_ Solidity rejects direct conversions and forces multi-step chains like `uint32(uint64(_gateKey))` and `uint16(uint160(tx.origin))`.

#### 1. Same-Size Rule for Cross-Type Casts (`address` $\leftrightarrow$ `uint` $\leftrightarrow$ `bytesN`)

In Solidity `0.8+`, you **cannot** convert across different type categories (`address`, `uint`, `bytesN`) and change the bit width in the same step:

| Cast Attempt                                             | Valid? | Reason                                                                                                                                                                   |
| :------------------------------------------------------- | :----: | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `uint32(_gateKey)` (`bytes8` $\rightarrow$ `uint32`)     |   ❌   | Crosses `bytes` $\rightarrow$ `uint` AND shrinks 64 bits $\rightarrow$ 32 bits (`uint` keeps right bytes, `bytes` keeps left bytes, so shrinking directly is ambiguous). |
| `uint64(_gateKey)` (`bytes8` $\rightarrow$ `uint64`)     |   ✅   | Both are **64 bits (8 bytes)** — pure reinterpretation.                                                                                                                  |
| `uint16(tx.origin)` (`address` $\rightarrow$ `uint16`)   |   ❌   | Crosses `address` $\rightarrow$ `uint` AND changes size (160 bits $\rightarrow$ 16 bits).                                                                                |
| `uint160(tx.origin)` (`address` $\rightarrow$ `uint160`) |   ✅   | Both are **160 bits (20 bytes)** (`address` is 20 bytes).                                                                                                                |
| `uint64(uint160(tx.origin))`                             |   ✅   | Same family (`uint160` $\rightarrow$ `uint64`), so resizing is allowed.                                                                                                  |
| `bytes8(uint64_val)` (`uint64` $\rightarrow$ `bytes8`)   |   ✅   | Both are **64 bits (8 bytes)**.                                                                                                                                          |

**Rule of thumb**: First convert across families at the **same bit width** (`bytes8` $\leftrightarrow$ `uint64`, `address` $\leftrightarrow$ `uint160`), then resize within the `uint` (or `bytes`) family.

#### 2. Downcasting (Narrowing) vs. Implicit Upcasting (Widening in Comparisons)

- **Downcasting inside `uint` (`uint160` $\rightarrow$ `uint64` $\rightarrow$ `uint32` $\rightarrow$ `uint16`)**:
  Always truncates from the **left** (drops higher-order bits) and keeps the **rightmost (least-significant) bytes**.
  _(Contrast with Level 12 Privacy: downcasting `bytes32` $\rightarrow$ `bytes16` keeps the leftmost bytes because fixed `bytesN` values are left-aligned.)_
- **Implicit Upcasting during `==` and `!=`**:
  When comparing two different `uint` widths (`uint32 == uint16` or `uint32 != uint64`), Solidity **zero-pads the smaller integer on the left** to match the larger width:
  - **Part 1** (`uint32` vs. `uint16`): `0x305c` (`uint16`) widens to `0x0000305c` (`uint32`) before comparing with `0xCCCCDDDD`.
  - **Part 2** (`uint32` vs. `uint64`): `0x0000305c` (`uint32`) widens to `0x000000000000305c` (`uint64`) before comparing with `0xAAAABBBBCCCCDDDD`.

#### 3. End-to-End Trace Using Test Address `0x44E97aF4418b7a17AABD8090bEA0A471a366305C`

1. `tx.origin` (`address`, 20 bytes / 40 hex chars):
   `0x44E97aF4418b7a17AABD8090bEA0A471a366305C`
2. `uint160(tx.origin)` (`uint160`, same 20 bytes):
   `0x44E97aF4418b7a17AABD8090bEA0A471a366305C`
3. `uint64(...)` (narrowed to lowest 8 bytes / 16 hex chars):
   `0xbEA0A471a366305C`
4. `& 0xFFFFFFFF0000FFFF` (zeroes out middle `[CCCC]` = `a366`):
   `0xbEA0A4710000305C`
5. `bytes8(...)` (reinterpreted as 64-bit `bytes8` `_gateKey`):
   `0xbea0a4710000305c`
6. Inside `gateThree`:
   - `uint64(_gateKey)` = `0xbea0a4710000305c`
   - `uint32(uint64(_gateKey))` = `0x0000305c`
   - `uint16(uint64(_gateKey))` = `0x305c`
   - `uint16(uint160(tx.origin))` = `0x305c`
   - Checks evaluated:
     - **Part 1**: `0x0000305c == 0x0000305c` (`uint16` zero-padded on left) $\rightarrow$ `true`
     - **Part 2**: `0x000000000000305c != 0xbea0a4710000305c` (`uint32` zero-padded on left) $\rightarrow$ `true`
     - **Part 3**: `0x0000305c == 0x0000305c` (`uint16` zero-padded on left) $\rightarrow$ `true`

---

### Gate 3: Integer Truncation & Bitmasking (`bytes8 _gateKey`)

`_gateKey` is 8 bytes (`uint64` = 16 hex characters). Visualizing `_gateKey` as four 2-byte blocks `0x [AAAA] [BBBB] [CCCC] [DDDD]`:

```text
uint64(_gateKey)           -> 0x AAAA BBBB CCCC DDDD   (all 8 bytes)
uint32(uint64(_gateKey))   -> 0x           CCCC DDDD   (lowest 4 bytes)
uint16(uint64(_gateKey))   -> 0x                DDDD   (lowest 2 bytes)
```

Tracing all three `require` checks on integer downcasting (integer casts drop upper bits on the left and keep the rightmost bytes):

1. **Part One**: `uint32(uint64(_gateKey)) == uint16(uint64(_gateKey))`
   - Compares `0x00000000CCCCDDDD` against `0x000000000000DDDD`.
   - Constraint: **`[CCCC]` must be `0000`**.
2. **Part Two**: `uint32(uint64(_gateKey)) != uint64(_gateKey)`
   - Compares `0x00000000CCCCDDDD` against `0xAAAABBBBCCCCDDDD`.
   - If `[AAAA][BBBB]` were `00000000`, the leading zeros wouldn't change the numeric value and both sides would be equal.
   - Constraint: **At least one bit in `[AAAA][BBBB]` must be non-zero**.
3. **Part Three**: `uint32(uint64(_gateKey)) == uint16(uint160(tx.origin))`
   - `uint16(uint160(tx.origin))` extracts the last 2 bytes (last 4 hex characters) of `tx.origin`.
   - Combined with Part One (`[CCCC] == 0000`), **`[DDDD]` must equal the last 2 bytes of `tx.origin`**.

#### Constructing `_gateKey` with a Bitmask

Taking the lowest 8 bytes of `tx.origin` (`uint64(uint160(tx.origin))`) and applying `& 0xFFFFFFFF0000FFFF`:

- `F` (`1111` in binary) preserves those hex nibbles (`AAAA BBBB` and `DDDD`).
- `0` (`0000` in binary) zeroes out `CCCC`.

```solidity
bytes8 gateKey = bytes8(uint64(uint160(tx.origin)) & 0xFFFFFFFF0000FFFF);
```

Example: if `tx.origin` ends in `0x1111222233334444`:

```text
  0x1111222233334444
& 0xFFFFFFFF0000FFFF
--------------------
= 0x1111222200004444
```

_(Note: for any hypothetical vanity address whose bits `[32..63]` are all zero, OR-ing with `0x0000000100000000` guarantees Part Two also stays non-zero.)_

---

## 4. Exploit Execution & Verification

### Attacker Contract (`src/attackers/GatekeeperOneAttack.sol`)

1. Builds `gateKey = bytes8(uint64(uint160(tx.origin)) & 0xFFFFFFFF0000FFFF)`.
2. Loops `i` from `0` to `8190`, forwarding `(8191 * 3) + i` gas via `address(target).call`.
3. Records `winningGasOffset = i` and exits as soon as `success == true`.

### Local Foundry Test (`test/13-GatekeeperOne.t.sol`)

```bash
forge test --match-contract GatekeeperOneTest -vvv
```

```text
Ran 3 tests for test/13-GatekeeperOne.t.sol:GatekeeperOneTest
[PASS] test_ExploitAllThreeGates() (gas: 304121)
Logs:
  Local PoC Success: Passed Gate 2 with gas offset: 265
  Entrant is now: 0x44E97aF4418b7a17AABD8090bEA0A471a366305C

[PASS] test_GateThreeKeyBitmaskSatisfiesAllThreeParts() (gas: 2876)
[PASS] test_InitialEntrantIsZero() (gas: 7818)
Suite result: ok. 3 passed; 0 failed; 0 skipped; finished in 4.37ms (3.49ms CPU time)
```

In this local Solc 0.8.30 compilation, Gate 2 aligned at **`winningGasOffset = 265`** (sending `(8191 * 3) + 265 = 24,838` gas into `enter`).

### Live Execution (`script/13-GatekeeperOne.s.sol`)

```bash
make sim LEVEL=13
make exploit LEVEL=13
```

---

## 5. Key Security Takeaways

1. **Never rely on `gasleft()` parity for access control or fairness**: Exact gas consumption shifts with compiler versions, optimizer flags, and EIP gas schedule changes (e.g., Berlin/Shanghai/Cancun opcode repricing), and callers can always meter sub-calls via `.call{gas: ...}`.
2. **`msg.sender != tx.origin` is trivially bypassed by any smart contract** (and blocks legitimate contract wallets / AA accounts if used inversely).
3. **Downcasting (`uint32` / `uint16` / `uint64`) silently discards upper bits**: Always use explicit checks (like OpenZeppelin `SafeCast`) if narrowing values from larger types.
