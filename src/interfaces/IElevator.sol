// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBuilding {
    function isLastFloor(uint256) external returns (bool);
}

interface IElevator {
    function top() external view returns (bool);
    function floor() external view returns (uint256);
    function goTo(uint256 _floor) external;
}
