// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFallout {
    function Fal1out() external payable;
    function allocate() external payable;
    function sendAllocation(address payable allocator) external;
    function collectAllocations() external;
    function allocatorBalance(address allocator) external view returns (uint256);
    function owner() external view returns (address);
}
