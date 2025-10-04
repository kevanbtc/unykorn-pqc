// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

interface Vm {
    // Minimal subset used by tests (cheatcodes)
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
}
