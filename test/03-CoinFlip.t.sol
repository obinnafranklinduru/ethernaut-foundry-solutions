// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CoinFlip} from "../src/03-CoinFlip.sol";
import {CoinFlipAttack} from "../src/challenges/CoinFlipAttack.sol";

contract CoinFlipTest is Test {
    CoinFlip public coinFlip;
    CoinFlipAttack public attacker;

    function setUp() public {
        coinFlip = new CoinFlip();
        attacker = new CoinFlipAttack(address(coinFlip));
    }

    function test_Attack10ConsecutiveWins() public {
        for (uint256 i = 0; i < 10; i++) {
            // Advance the block number by 1 for each flip
            vm.roll(block.number + 1);

            attacker.attack();

            assertEq(coinFlip.consecutiveWins(), i + 1, "Win count did not increment");
        }

        assertEq(coinFlip.consecutiveWins(), 10, "Failed to achieve 10 wins");
        console2.log("Verified locally: 10 consecutive wins achieved!");
    }
}
