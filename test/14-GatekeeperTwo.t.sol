// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {GatekeeperTwo} from "../src/14-GatekeeperTwo.sol";
import {GatekeeperTwoAttack} from "../src/attackers/GatekeeperTwoAttack.sol";

contract GatekeeperTwoTest is Test {
    GatekeeperTwo public gatekeeper;

    address public player = makeAddr("player");

    function setUp() public {
        gatekeeper = new GatekeeperTwo();
    }

    function test_InitialEntrantIsZero() public view {
        assertEq(gatekeeper.entrant(), address(0), "Entrant should initially be zero address");
    }

    function test_ConstructorExploitPassesAllThreeGates() public {
        // Use two-argument vm.prank(msgSender, txOrigin) so tx.origin == player
        vm.prank(player, player);

        // Deploying GatekeeperTwoAttack runs the attack inside its constructor while extcodesize == 0
        GatekeeperTwoAttack attackerContract = new GatekeeperTwoAttack(address(gatekeeper));

        assertEq(gatekeeper.entrant(), player, "Entrant was not set to player");
        assertGt(address(attackerContract).code.length, 0, "Runtime bytecode should exist post-deployment");

        console2.log("Local PoC Success: Attack executed during constructor!");
        console2.log("Gate key used:");
        console2.logBytes8(attackerContract.gateKeyUsed());
        console2.log("Attacker runtime extcodesize post-deploy:", address(attackerContract).code.length);
        console2.log("Entrant is now:", gatekeeper.entrant());
    }
}
