// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {GatekeeperOne} from "../src/13-GatekeeperOne.sol";
import {GatekeeperOneAttack} from "../src/attackers/GatekeeperOneAttack.sol";

contract GatekeeperOneTest is Test {
    GatekeeperOne public gatekeeper;
    GatekeeperOneAttack public attackerContract;

    address public player = makeAddr("player");

    function setUp() public {
        gatekeeper = new GatekeeperOne();

        vm.prank(player);
        attackerContract = new GatekeeperOneAttack(address(gatekeeper));
    }

    function test_InitialEntrantIsZero() public view {
        assertEq(gatekeeper.entrant(), address(0), "Entrant should initially be zero address");
    }

    function test_GateThreeKeyBitmaskSatisfiesAllThreeParts() public view {
        bytes8 gateKey = bytes8(uint64(uint160(player)) & 0xFFFFFFFF0000FFFF);

        // Part one: bytes [2..3] (CCCC) must be 0000 so uint32 == uint16
        assertEq(uint32(uint64(gateKey)), uint16(uint64(gateKey)), "Failed gateThree part one");

        // Part two: upper 4 bytes (AAAA BBBB) must be non-zero so uint32 != uint64
        assertTrue(uint32(uint64(gateKey)) != uint64(gateKey), "Failed gateThree part two");

        // Part three: lower 2 bytes (DDDD) must match the last 2 bytes of tx.origin
        assertEq(uint32(uint64(gateKey)), uint16(uint160(player)), "Failed gateThree part three");
    }

    function test_ExploitAllThreeGates() public {
        // Use two-argument vm.prank(msgSender, txOrigin) so tx.origin == player
        vm.prank(player, player);
        attackerContract.attack();

        assertEq(gatekeeper.entrant(), player, "Entrant was not set to player");
        console2.log("Local PoC Success: Passed Gate 2 with gas offset:", attackerContract.winningGasOffset());
        console2.log("Entrant is now:", gatekeeper.entrant());
    }
}
