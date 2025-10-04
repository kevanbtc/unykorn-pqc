// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MonthlyDigest {
    event MonthlyPinned(uint32 indexed yyyymm, bytes32 bookRoot, bytes32 cidHash, address indexed by);
    mapping(uint32=>bytes32) public rootForMonth;
    mapping(uint32=>bytes32) public cidForMonth;

    error AlreadyPinned();

    function pin(uint32 yyyymm, bytes32 root, bytes32 cidHash) external {
        if (rootForMonth[yyyymm] != bytes32(0)) revert AlreadyPinned();
        rootForMonth[yyyymm] = root;
        cidForMonth[yyyymm] = cidHash;
        emit MonthlyPinned(yyyymm, root, cidHash, msg.sender);
    }
}
