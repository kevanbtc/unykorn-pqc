// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "./Vm.sol";

contract Test {
    Vm public constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    function assertTrue(bool cond, string memory message) internal pure {
        if (!cond) revert(message);
    }
    function assertEq(uint256 a, uint256 b) internal pure {
        if (a != b) revert("assertEq failed");
    }
}
