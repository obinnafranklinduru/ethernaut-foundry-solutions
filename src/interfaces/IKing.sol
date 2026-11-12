// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IKing {
    function prize() external view returns (uint256);
    function _king() external view returns (address);
    function owner() external view returns (address);
}
