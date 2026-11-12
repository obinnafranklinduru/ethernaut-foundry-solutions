// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVault {
    function locked() external view returns (bool);
    function unlock(bytes32 _password) external;
}
