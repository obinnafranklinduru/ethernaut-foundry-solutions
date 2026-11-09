# 01 - Fallback

## 1. Challenge Overview

- **Objective**: Claim ownership of the contract and reduce its balance to 0.
- **Contract Type**: Access control flaw / Fallback function misuse.

---

## 2. Vulnerability Analysis

### The Flaw

The contract contains two state-altering paths that modify the `owner` variable:

1. **`contribute()` Function**:

   ```solidity
   function contribute() public payable {
       require(msg.value < 0.001 ether);
       contributions[msg.sender] += msg.value;
       if (contributions[msg.sender] > contributions[owner]) {
           owner = msg.sender;
       }
   }
   ```

   - In the constructor, `contributions[msg.sender] = 1000 * (1 ether)`.
   - Because `contribute()` restricts each contribution to `< 0.001 ether`, surpassing 1000 ETH via `contribute()` would take over 1,000,000 transactions. This path is financially and practically infeasible.

2. **`receive()` Special Function**:

   ```solidity
   receive() external payable {
       require(msg.value > 0 && contributions[msg.sender] > 0);
       owner = msg.sender;
   }
   ```

   - The `receive()` function is triggered when the contract receives plain Ether with empty `calldata`.
   - It requires two conditions:
     1. `msg.value > 0`: Must send at least 1 wei.
     2. `contributions[msg.sender] > 0`: The sender must have contributed at least once previously.
   - Crucially, if both conditions are met, it blindly sets `owner = msg.sender`!

---

## 3. Exploit Strategy

1. **Become a Contributor**: Call `contribute()` with `< 0.001 ether` (e.g., `0.0001 ether`). This satisfies `contributions[msg.sender] > 0`.
2. **Trigger `receive()`**: Send 1 wei directly to the contract address with empty calldata (`call{value: 1 wei}("")`). This triggers `receive()` and overwrites `owner = msg.sender`.
3. **Drain Balance**: Call `withdraw()`, which is now permitted because the `onlyOwner` check passes.

---

## 4. Verification & Testing

### Local Unit Test

A local Proof of Concept test is available at `test/01-Fallback.t.sol`.
Run it via:

```bash
make test-fallback
```

### On-Chain Script Execution

The script is located at `script/01-Fallback.s.sol`.

1. **Simulate against live network (dry run)**:

   ```bash
   make sim LEVEL=01
   ```

2. **Broadcast on-chain**:

   ```bash
   make exploit LEVEL=01
   ```

3. **Inspect state with Cast**:

   ```bash
   make owner
   make balance
   ```

---

## 5. Security Takeaways & Mitigation

- **Never mutate critical access control state in fallback/receive functions**: Fallback functions are meant to accept ether or handle unmatched calls, not grant administrative control.
- **Explicit Access Control**: Administrative roles should only be transferred through a secure, two-step transfer pattern (e.g. OpenZeppelin's `Ownable2Step`) where the pending owner must explicitly accept ownership.
