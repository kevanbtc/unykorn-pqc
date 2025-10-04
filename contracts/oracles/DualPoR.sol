// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IProofOfReserves} from "../interfaces/IProofOfReserves.sol";

/**
 * @title DualPoR - Dual Proof-of-Reserves Oracle with Divergence Detection
 * @notice Wraps two independent PoR feeds and provides divergence monitoring
 * @dev Returns conservative minimum ratio and emits alerts when feeds diverge
 */
contract DualPoR is IProofOfReserves {
    // --- State Variables ---
    IProofOfReserves public primary;
    IProofOfReserves public backup;
    uint32 public maxDivergenceBps; // e.g., 100 = 1%
    
    // --- Events ---
    event DivergenceAlert(uint256 p, uint256 b, uint256 diffBps, uint40 ts);

    // --- Constructor ---
    /**
     * @param _p Primary PoR oracle address
     * @param _b Backup PoR oracle address
     * @param _maxDivBps Maximum allowed divergence in basis points
     */
    constructor(address _p, address _b, uint32 _maxDivBps) {
        primary = IProofOfReserves(_p); 
        backup = IProofOfReserves(_b); 
        maxDivergenceBps = _maxDivBps;
    }

    // --- Public Functions ---
    /**
     * @notice Returns the conservative minimum PoR ratio from both oracles
     * @dev Calculates divergence but cannot emit in view function
     * @return Conservative minimum ratio in basis points
     */
    function ratioBps() public view returns (uint256) {
        uint256 rp = primary.ratioBps();
        uint256 rb = backup.ratioBps();
        uint256 diff = rp > rb ? rp - rb : rb - rp;
        uint256 denom = ((rp + rb) / 2);
        uint256 diffBps = (diff * 10_000) / (denom == 0 ? 1 : denom);
        
        // Note: divergence detected but cannot emit in view function
        // Use checkDivergence() in transaction paths for alerts
        
        return rp < rb ? rp : rb; // conservative minimum
    }

    /**
     * @notice Checks if PoR ratio meets minimum requirement
     * @param minBps Minimum required ratio in basis points
     * @return True if ratio >= minBps
     */
    function requireAbove(uint256 minBps) external view returns (bool) {
        return ratioBps() >= minBps;
    }

    /**
     * @notice Active divergence check (transaction path)
     * @dev Emits DivergenceAlert if feeds diverge beyond threshold
     * @return ok True if divergence is within acceptable bounds
     */
    function checkDivergence() external returns (bool ok) {
        uint256 rp = primary.ratioBps(); 
        uint256 rb = backup.ratioBps();
        uint256 diff = rp > rb ? rp - rb : rb - rp;
        uint256 denom = ((rp + rb) / 2);
        uint256 diffBps = (diff * 10_000) / (denom == 0 ? 1 : denom);
        
        ok = diffBps <= maxDivergenceBps;
        if (!ok) emit DivergenceAlert(rp, rb, diffBps, uint40(block.timestamp));
    }
}
