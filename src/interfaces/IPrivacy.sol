// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPrivacy {
    function locked() external view returns (bool);
    function ID() external view returns (uint256);
    function unlock(bytes16 _key) external;
}
