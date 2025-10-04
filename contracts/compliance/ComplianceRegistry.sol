// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IComplianceRegistryExtended} from "../interfaces/IComplianceRegistryExtended.sol";

/**
 * @title ComplianceRegistry - Jurisdiction-Aware Compliance Management
 * @notice Manages user compliance profiles and jurisdiction-specific policies
 * @dev Stores KYC status, risk tiers, accreditation levels, and jurisdiction rules
 */
contract ComplianceRegistry is IComplianceRegistryExtended {
    // --- State Variables ---
    mapping(address => ComplianceProfile) private _p;

    /**
     * @dev Jurisdictional policy configuration
     */
    struct JurisdictionPolicy {
        uint96 travelRuleThreshold; // e.g., 3_000e6 (US), 1_000e6 (EU)
        uint32 carMinBps;           // capital adequacy / PoR min (e.g., 12000 = 120%)
    }
    mapping(Jurisdiction => JurisdictionPolicy) public jp;

    address public admin;
    
    // --- Errors ---
    error NotAdmin();

    // --- Constructor ---
    /**
     * @notice Initializes registry with default jurisdiction policies
     */
    constructor() {
        admin = msg.sender;
        // Default Travel Rule thresholds and CAR minimums by jurisdiction
        jp[Jurisdiction.US]  = JurisdictionPolicy({travelRuleThreshold: 3_000e6, carMinBps: 12000});
        jp[Jurisdiction.EU]  = JurisdictionPolicy({travelRuleThreshold: 1_000e6, carMinBps: 11000});
        jp[Jurisdiction.UAE] = JurisdictionPolicy({travelRuleThreshold: 3_600e6, carMinBps: 12000});
        jp[Jurisdiction.UK]  = JurisdictionPolicy({travelRuleThreshold: 1_000e6, carMinBps: 11000});
    }

    // --- Modifiers ---
    modifier onlyAdmin() { 
        if (msg.sender != admin) revert NotAdmin(); 
        _; 
    }

    // --- Admin Functions ---
    /**
     * @notice Sets compliance profile for a user
     * @param u User address
     * @param c Compliance profile struct
     */
    function setProfile(address u, ComplianceProfile calldata c) external onlyAdmin { 
        _p[u] = c; 
    }

    /**
     * @notice Updates jurisdiction policy parameters
     * @param j Jurisdiction enum
     * @param trThresh Travel Rule threshold in base units
     * @param carMin Capital adequacy ratio minimum in basis points
     */
    function setJurisdictionPolicy(Jurisdiction j, uint96 trThresh, uint32 carMin) external onlyAdmin {
        jp[j] = JurisdictionPolicy({travelRuleThreshold: trThresh, carMinBps: carMin});
    }

    // --- View Functions ---
    /**
     * @notice Returns full compliance profile for a user
     */
    function profile(address u) external view returns (ComplianceProfile memory) { 
        return _p[u]; 
    }

    /**
     * @notice Checks if user is whitelisted (active and KYC verified)
     */
    function isWhitelisted(address u) external view returns (bool) { 
        return _p[u].active && _p[u].kyc != KYCStatus.NONE; 
    }

    /**
     * @notice Returns user's jurisdiction
     */
    function jurisdiction(address u) external view returns (Jurisdiction) { 
        return _p[u].j; 
    }

    /**
     * @notice Checks if user is accredited investor
     */
    function requireAccredited(address u) external view returns (bool) { 
        return _p[u].acc == AccLevel.ACCREDITED || _p[u].acc == AccLevel.QIB_144A; 
    }

    /**
     * @notice Returns Travel Rule threshold for user based on jurisdiction
     */
    function travelRuleThresholdOf(address u) external view returns (uint96) {
        return jp[_p[u].j].travelRuleThreshold;
    }

    /**
     * @notice Returns minimum CAR/PoR requirement for user based on jurisdiction
     */
    function carMinBpsOf(address u) external view returns (uint32) {
        return jp[_p[u].j].carMinBps;
    }

    // --- Rolling Window (Placeholder) ---
    /**
     * @dev Placeholder for rolling window usage tracking
     */
    function touch24h(address, uint256) external {}
}
