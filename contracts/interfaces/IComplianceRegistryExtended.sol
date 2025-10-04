// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IComplianceRegistryExtended {
    enum Jurisdiction { US, EU, UAE, UK, OTHER }
    enum KYCStatus { NONE, BASIC, FULL }
    enum RiskTier { LOW, MEDIUM, HIGH }
    enum AccLevel { NONE, ACCREDITED, QIB_144A }

    struct ComplianceProfile {
        bool active;
        Jurisdiction j;
        KYCStatus kyc;
        RiskTier risk;
        AccLevel acc;
        bool pep;
        uint64 lockupEnd;
        uint96 dailyLimit;
        uint96 outstanding24h;
        bytes32 pqPkHash;
    }

    // Core profile
    function profile(address u) external view returns (ComplianceProfile memory);
    function setProfile(address u, ComplianceProfile calldata c) external;
    function isWhitelisted(address u) external view returns (bool);
    function jurisdiction(address u) external view returns (Jurisdiction);
    function requireAccredited(address u) external view returns (bool);

    // Jurisdiction helpers
    function travelRuleThresholdOf(address u) external view returns (uint96);
    function carMinBpsOf(address u) external view returns (uint32);

    // Usage rolling window touch (no-op in minimal impl)
    function touch24h(address u, uint256 amt) external;
}
