// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct TravelRuleProof {
    bytes32 sessionId;
    bytes32 ivmsHash;
    address originator;
    address beneficiary;
}

interface ITravelRuleRegistry {
    function record(TravelRuleProof calldata p) external;
    function exists(bytes32 sid) external view returns (bool);
}
