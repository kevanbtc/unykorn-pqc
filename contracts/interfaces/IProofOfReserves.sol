// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IProofOfReserves {
    function ratioBps() external view returns (uint256);
    function requireAbove(uint256 minBps) external view returns (bool);
}
