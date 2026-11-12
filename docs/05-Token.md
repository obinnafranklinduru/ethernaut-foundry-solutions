# 05 - Token

## 1. Challenge Overview

- **Objective**: You start with 20 tokens. Gain a massive number of tokens to beat the level.
- **Vulnerability Category**: Integer Underflow / Pre-Solidity 0.8 Wrapping Arithmetic (SWC-101).

---

## 2. Contract Source Code

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Token {
    mapping(address => uint256) balances;
    uint256 public totalSupply;

    constructor(uint256 _initialSupply) public {
        balances[msg.sender] = totalSupply = _initialSupply;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(balances[msg.sender] - _value >= 0);
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        return true;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }
}
```

---

## 3. Vulnerability Analysis

### The Flaw

The vulnerability resides in the `transfer` function:

```solidity
require(balances[msg.sender] - _value >= 0);
balances[msg.sender] -= _value;
balances[_to] += _value;
```

1. **Pre-Solidity 0.8.0 Math**: Prior to version `0.8.0`, Solidity arithmetic did not revert on overflow or underflow by default. Integers wrapped modulo $2^{256}$.
2. **Unsigned Integer Axiom**: Both `balances[msg.sender]` and `_value` are unsigned 256-bit integers (`uint256`). By mathematical definition, an unsigned integer **can never be negative**.
3. **The Flawed `require`**:
   - If `balances[msg.sender] == 20` and `_value == 21`:
   - $20 - 21$ underflows to $2^{256} - 1$ (`115792089237316195423570985008687907853269984665640564039457584007913129639935`).
   - Is that number $\ge 0$? **Yes!**
   - The `require` check passes unconditionally.
4. **Balance Manipulation**:
   - In the next line: `balances[msg.sender] -= 21;`
   - The caller's balance underflows to $2^{256} - 1$ (~$1.157 \times 10^{77}$ tokens).

---

## 4. Exploit Architecture

### Interface (`src/interfaces/IToken.sol`)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IToken {
    function transfer(address _to, uint256 _value) external returns (bool);
    function balanceOf(address _owner) external view returns (uint256 balance);
    function totalSupply() external view returns (uint256);
}
```

### Exploit Script (`script/05-Token.s.sol`)

1. Checks the player's balance.
2. If $\le 20$, calls `target.transfer(address(0xdead), 21)`.
3. Verifies that the balance has underflowed to an astronomical quantity.

### Proof-of-Concept Test (`test/05-Token.t.sol`)

Replicated the pre-0.8 wrapping behavior using Solidity 0.8 `unchecked { ... }`:

```bash
forge test --match-contract TokenTest -vvvv
```

Result: Player balance transitions from `20` to `type(uint256).max`.

---

## 5. Real-World Case Study: BeautyChain (BEC) Token (2018)

In April 2018, the **BeautyChain (BEC)** ERC-20 token suffered a catastrophic attack known as `batchOverflow`.

A function `batchTransfer` calculated `amount = uint256(cnt) * _value`. An attacker passed a massive `_value` and `cnt = 2`, causing the product to overflow and wrap around to `0`. The contract verified that the sender had $\ge 0$ balance, then credited the two recipient addresses with astronomical quantities of tokens out of thin air, crashing the token's market cap to zero.

---

## 6. Prevention & Modern Solidity Standards

1. **Solidity 0.8.0+ Built-in Checked Arithmetic**: Arithmetic operations now revert automatically on overflow/underflow unless explicitly wrapped inside an `unchecked { ... }` block.
2. **For Legacy Code (< 0.8.0)**: Always use OpenZeppelin's `SafeMath` library (`.add()`, `.sub()`, `.mul()`, `.div()`).
3. **Correct Balance Validation**: When writing custom balance checks, always compare the operands before subtraction:

   ```solidity
   require(balances[msg.sender] >= _value, "Insufficient balance");
   ```
