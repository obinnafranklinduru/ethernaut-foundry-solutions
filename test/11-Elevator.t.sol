// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Elevator} from "../src/11-Elevator.sol";
import {ElevatorAttack} from "../src/attackers/ElevatorAttack.sol";

contract ElevatorTest is Test {
    Elevator public elevator;
    ElevatorAttack public attackerContract;

    address public attacker = makeAddr("attacker");

    function setUp() public {
        elevator = new Elevator();

        vm.prank(attacker);
        attackerContract = new ElevatorAttack(address(elevator));
    }

    function test_InitialElevatorState() public view {
        assertFalse(elevator.top());
        assertEq(elevator.floor(), 0);
    }

    function test_ReachTopFloorExploit() public {
        vm.prank(attacker);
        attackerContract.attack();

        assertEq(elevator.floor(), 1, "Elevator did not move to floor 1");
        assertTrue(elevator.top(), "Elevator did not reach the top");
        assertEq(attackerContract.count(), 2, "isLastFloor was not called twice");
        console2.log("Local PoC Success: Elevator top is", elevator.top(), "at floor", elevator.floor());
    }
}
