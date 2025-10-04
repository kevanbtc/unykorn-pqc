// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IComplianceRegistryExtended} from "../interfaces/IComplianceRegistryExtended.sol";

contract ComplianceRegistry is IComplianceRegistryExtended {
    mapping(address => ComplianceProfile) private _p;

    // Jurisdictional knobs
    struct JurisdictionPolicy {
        uint96 travelRuleThreshold; // e.g., 3_000e6 (US), 1_000e6 (EU)
        uint32 carMinBps;           // capital adequacy / PoR min (e.g., 12000 = 120%)
    }
    mapping(Jurisdiction => JurisdictionPolicy) public jp;

    address public admin;
    error NotAdmin();

    constructor() {
        admin = msg.sender;
        jp[Jurisdiction.US]  = JurisdictionPolicy({travelRuleThreshold: 3_000e6, carMinBps: 12000});
        jp[Jurisdiction.EU]  = JurisdictionPolicy({travelRuleThreshold: 1_000e6, carMinBps: 11000});
        jp[Jurisdiction.UAE] = JurisdictionPolicy({travelRuleThreshold: 3_600e6, carMinBps: 12000});
        jp[Jurisdiction.UK]  = JurisdictionPolicy({travelRuleThreshold: 1_000e6, carMinBps: 11000});
    }

    modifier onlyAdmin(){ if (msg.sender!=admin) revert NotAdmin(); _; }

    function setProfile(address u, ComplianceProfile calldata c) external onlyAdmin { _p[u] = c; }
    function profile(address u) external view returns (ComplianceProfile memory){ return _p[u]; }
    function isWhitelisted(address u) external view returns (bool){ return _p[u].active && _p[u].kyc != KYCStatus.NONE; }
    function jurisdiction(address u) external view returns (Jurisdiction){ return _p[u].j; }
    function requireAccredited(address u) external view returns (bool){ return _p[u].acc == AccLevel.ACCREDITED || _p[u].acc == AccLevel.QIB_144A; }

    // rolling window usage (already scaffolded in your earlier version)
    function touch24h(address, uint256) external {}

    // NEW: helpers
    function travelRuleThresholdOf(address u) external view returns (uint96) {
        return jp[_p[u].j].travelRuleThreshold;
    }
    function carMinBpsOf(address u) external view returns (uint32) {
        return jp[_p[u].j].carMinBps;
    }

    function setJurisdictionPolicy(IComplianceRegistryExtended.Jurisdiction j, uint96 trThresh, uint32 carMin) external onlyAdmin {
        jp[j] = JurisdictionPolicy({travelRuleThreshold: trThresh, carMinBps: carMin});
    }
}
