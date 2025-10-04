// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title MonthlyDigest - Audit Trail Anchoring
 * @notice Pins monthly audit digests on-chain for transparency and immutability
 * @dev Each month can only be pinned once, preventing replay or modification
 */
contract MonthlyDigest {
    // --- Events ---
    event MonthlyPinned(uint32 indexed yyyymm, bytes32 bookRoot, bytes32 cidHash, address indexed by);
    
    // --- State Variables ---
    mapping(uint32 => bytes32) public rootForMonth;
    mapping(uint32 => bytes32) public cidForMonth;

    // --- Errors ---
    error AlreadyPinned();

    /**
     * @notice Pins a monthly audit digest
     * @dev Can only be called once per yyyymm. Operational flow:
     *      1. CI/cron aggregates daily ledger roots into monthly JSON
     *      2. JSON is pinned to IPFS
     *      3. This function is called with the root hash and CID hash
     * @param yyyymm Year-month in format YYYYMM (e.g., 202501 for January 2025)
     * @param root Merkle root of the monthly ledger aggregate
     * @param cidHash Keccak256 hash of the IPFS CID
     */
    function pin(uint32 yyyymm, bytes32 root, bytes32 cidHash) external {
        if (rootForMonth[yyyymm] != bytes32(0)) revert AlreadyPinned();
        rootForMonth[yyyymm] = root;
        cidForMonth[yyyymm] = cidHash;
        emit MonthlyPinned(yyyymm, root, cidHash, msg.sender);
    }
}
