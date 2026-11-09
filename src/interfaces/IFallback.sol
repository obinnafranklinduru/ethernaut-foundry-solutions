// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFallback {
    function contribute() external payable;
    function owner() external view returns (address);
    function withdraw() external;
}
