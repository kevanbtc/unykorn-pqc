# Unykorn PQC

**Post-Quantum Ready, Compliance-Aware Stablecoin Infrastructure**

This repository provides production-grade smart contract pillars for building compliant, post-quantum-ready stablecoins with jurisdiction-aware controls, automated audit trails, and dual oracle resilience.

## 🎯 Overview

Unykorn PQC includes three core compliance pillars:

1. **Jurisdiction-Aware Thresholds** - Dynamic Travel Rule and CAR/PoR requirements based on user jurisdiction
2. **Monthly Audit Anchors** - Immutable on-chain audit digest pinning for transparency
3. **Dual PoR with Divergence Guard** - Redundant oracle feeds with automatic divergence detection and circuit-breaking

## ✨ Key Features

- 🌍 **Multi-Jurisdiction Support**: Pre-configured policies for US, EU, UAE, UK
- 🔐 **Post-Quantum Ready**: Scaffolding for PQ signature verification (CRYSTALS-Dilithium compatible)
- 🛡️ **Auto-Pause Mechanism**: Circuit breaker triggers on PoR oracle divergence
- 📊 **Audit Trail**: Monthly digest pinning for regulatory compliance
- 🚦 **Travel Rule Enforcement**: Automatic threshold enforcement with session-based validation
- 💎 **Conservative Oracle**: Always returns minimum of dual PoR feeds

## 📋 Architecture

### Core Contracts

```
contracts/
├── TGUSD.sol                  # Main stablecoin with compliance hooks
├── compliance/
│   └── ComplianceRegistry.sol # User profiles & jurisdiction policies
├── oracles/
│   └── DualPoR.sol           # Dual Proof-of-Reserves oracle
└── audit/
    └── MonthlyDigest.sol     # Monthly audit digest anchoring
```

### Contract Interactions

```
┌─────────────┐
│   TGUSD     │ Stablecoin with compliance integration
└──────┬──────┘
       │
       ├──────▶ ComplianceRegistry (KYC, jurisdiction, thresholds)
       ├──────▶ TravelRuleRegistry (session validation)
       └──────▶ DualPoR (PoR verification & divergence check)
                   │
                   ├──────▶ Primary PoR Oracle
                   └──────▶ Backup PoR Oracle
```

## 🚀 Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Solidity ^0.8.24

### Installation

```bash
# Clone the repository
git clone https://github.com/kevanbtc/unykorn-pqc.git
cd unykorn-pqc

# Install dependencies
forge install

# Build contracts
forge build

# Run all tests
forge test -vv
```

### Run Focused Tests

```bash
# Test jurisdiction-aware thresholds
forge test --match-path test/Jurisdiction_Thresholds.t.sol -vv

# Test monthly digest anchoring
forge test --match-path test/MonthlyDigest.t.sol -vv

# Test PoR divergence detection
forge test --match-path test/DualPoR_Divergence.t.sol -vv
```

## 📖 Detailed Documentation

### 1. Jurisdiction Profiles → Dynamic Thresholds

The `ComplianceRegistry` contract manages user compliance profiles and jurisdiction-specific policies.

#### User Profile Structure

```solidity
struct ComplianceProfile {
    bool active;              // Profile enabled
    Jurisdiction j;           // US, EU, UAE, UK, OTHER
    KYCStatus kyc;           // NONE, BASIC, FULL
    RiskTier risk;           // LOW, MEDIUM, HIGH
    AccLevel acc;            // NONE, ACCREDITED, QIB_144A
    bool pep;                // Politically Exposed Person flag
    uint64 lockupEnd;        // Lockup expiration timestamp
    uint96 dailyLimit;       // Daily transaction limit
    uint96 outstanding24h;   // 24h rolling window usage
    bytes32 pqPkHash;        // Post-quantum public key hash
}
```

#### Jurisdiction Policies

Pre-configured defaults:

| Jurisdiction | Travel Rule Threshold | Min CAR (PoR) |
|--------------|----------------------|---------------|
| US           | 3,000 USDC          | 120%         |
| EU           | 1,000 USDC          | 110%         |
| UAE          | 3,600 USDC          | 120%         |
| UK           | 1,000 USDC          | 110%         |

#### Key Functions

- `travelRuleThresholdOf(user)` - Returns jurisdiction-specific Travel Rule threshold
- `carMinBpsOf(user)` - Returns minimum PoR/CAR requirement in basis points
- `setProfile(user, profile)` - Admin: Set user compliance profile
- `setJurisdictionPolicy(j, threshold, carMin)` - Admin: Update jurisdiction policy

#### Integration in TGUSD

```solidity
// Travel Rule enforcement
function transferLarge(address to, uint256 amt, bytes32 sessionId) external {
    uint96 threshold = COMP.travelRuleThresholdOf(msg.sender);
    if (amt >= threshold) {
        // Require valid Travel Rule session
    }
    _transfer(msg.sender, to, amt);
}

// CAR/PoR enforcement
function mintWithPQ(...) external {
    uint32 carMin = COMP.carMinBpsOf(msg.sender);
    require(IProofOfReserves(POR).requireAbove(carMin), "Insufficient PoR");
    _mint(to, amt);
}
```

### 2. Monthly Audit Anchors (Digest)

The `MonthlyDigest` contract provides immutable on-chain anchoring for monthly audit trails.

#### Features

- **One Pin Per Month**: Each `yyyymm` can only be pinned once (reverts on duplicate)
- **Dual Hash Storage**: Stores both Merkle root and IPFS CID hash
- **Event Emission**: Emits `MonthlyPinned` for off-chain indexing

#### Operational Workflow

1. **Aggregation**: CI/cron job collects daily ledger roots
2. **IPFS Pinning**: Monthly JSON blob is pinned to IPFS
3. **On-chain Anchor**: Call `pin(yyyymm, root, keccak256(cid))`

```solidity
// Example: Pin January 2025 audit
monthlyDigest.pin(
    202501,                           // yyyymm
    0x1234...,                        // Merkle root of monthly aggregate
    keccak256(bytes("QmHash..."))     // Hash of IPFS CID
);
```

#### Verification

```solidity
bytes32 root = monthlyDigest.rootForMonth(202501);
bytes32 cidHash = monthlyDigest.cidForMonth(202501);
```

### 3. Dual PoR with Divergence Guard

The `DualPoR` oracle wraps two independent Proof-of-Reserves feeds for redundancy and fraud detection.

#### Design Principles

- **Conservative**: Always returns the **minimum** ratio of both feeds
- **Divergence Detection**: Monitors feed discrepancy in basis points
- **Auto-Pause**: TGUSD halts minting if divergence exceeds threshold

#### Configuration Example

```solidity
// Deploy with 1% max divergence tolerance
DualPoR dualPor = new DualPoR(
    primaryOracleAddress,
    backupOracleAddress,
    100  // 100 bps = 1%
);
```

#### Divergence Calculation

```
diffBps = (|primary - backup| * 10,000) / average(primary, backup)
```

If `diffBps > maxDivergenceBps`, the `DivergenceAlert` event is emitted.

#### TGUSD Integration

```solidity
function mintWithPQ(...) external {
    // Check for divergence - auto-pause if detected
    (bool ok, ) = POR.call(abi.encodeWithSignature("checkDivergence()"));
    if (!ok) {
        paused = true;
        revert ProofOfReservesDivergence();
    }
    
    // Verify PoR meets jurisdiction minimum
    uint32 carMin = COMP.carMinBpsOf(msg.sender);
    require(IProofOfReserves(POR).requireAbove(carMin));
    
    _mint(to, amt);
}
```

## 🔐 Security Considerations

### Access Control

- **ComplianceRegistry**: Only `admin` can set profiles and jurisdiction policies
- **TGUSD**: Only `admin` can update registry/oracle addresses
- **MonthlyDigest**: Anyone can pin (consider restricting to authorized operators)

### Circuit Breakers

- **PoR Divergence**: TGUSD auto-pauses minting when oracle feeds diverge
- **Manual Pause**: Consider adding admin emergency pause function

### Audit Recommendations

1. ✅ All critical functions have proper access control
2. ✅ Custom errors for gas efficiency and clarity
3. ✅ Events emitted for state changes
4. ⚠️ Consider timelock for jurisdiction policy updates
5. ⚠️ Add multi-sig for admin operations in production

## 🧪 Development Workflow

### Running Tests

```bash
# Run all tests with verbosity
forge test -vv

# Run specific test file
forge test --match-path test/Jurisdiction_Thresholds.t.sol -vv

# Run tests with gas reporting
forge test --gas-report

# Run tests with coverage
forge coverage
```

### Code Formatting

```bash
# Format all Solidity files
forge fmt

# Check formatting without modifying
forge fmt --check
```

### Static Analysis

```bash
# Run Slither (requires installation)
slither .

# Generate function call graph
surya graph contracts/**/*.sol | dot -Tpng > graph.png
```

## 📦 Deployment Guide

### 1. Deploy Core Contracts

```solidity
// 1. Deploy ComplianceRegistry
ComplianceRegistry comp = new ComplianceRegistry();

// 2. Deploy MonthlyDigest
MonthlyDigest digest = new MonthlyDigest();

// 3. Deploy DualPoR (requires two PoR oracles)
DualPoR por = new DualPoR(primaryOracle, backupOracle, 100);

// 4. Deploy TGUSD
TGUSD tgusd = new TGUSD();
tgusd.setComplianceRegistry(address(comp));
tgusd.setProofOfReserves(address(por));
tgusd.setTravelRuleRegistry(travelRuleAddress);
```

### 2. Configure Jurisdictions (Optional)

```solidity
// Update EU policy
comp.setJurisdictionPolicy(
    IComplianceRegistryExtended.Jurisdiction.EU,
    1_500e6,  // New Travel Rule threshold
    11500     // New CAR minimum (115%)
);
```

### 3. Whitelist Users

```solidity
IComplianceRegistryExtended.ComplianceProfile memory profile = 
    IComplianceRegistryExtended.ComplianceProfile({
        active: true,
        j: IComplianceRegistryExtended.Jurisdiction.US,
        kyc: IComplianceRegistryExtended.KYCStatus.FULL,
        risk: IComplianceRegistryExtended.RiskTier.LOW,
        acc: IComplianceRegistryExtended.AccLevel.ACCREDITED,
        pep: false,
        lockupEnd: 0,
        dailyLimit: type(uint96).max,
        outstanding24h: 0,
        pqPkHash: bytes32(0)
    });

comp.setProfile(userAddress, profile);
```

## 📚 API Reference

### TGUSD

| Function | Description | Access |
|----------|-------------|--------|
| `transferLarge(to, amt, sessionId)` | Transfer with Travel Rule enforcement | Public |
| `mintWithPQ(to, amt, msgH, pkH, sigH)` | Mint with PQ signature verification | Public (KYC required) |
| `setComplianceRegistry(address)` | Update compliance registry | Admin |
| `setProofOfReserves(address)` | Update PoR oracle | Admin |
| `setTravelRuleRegistry(address)` | Update TR registry | Admin |

### ComplianceRegistry

| Function | Description | Access |
|----------|-------------|--------|
| `setProfile(user, profile)` | Set user compliance profile | Admin |
| `setJurisdictionPolicy(j, threshold, carMin)` | Update jurisdiction policy | Admin |
| `travelRuleThresholdOf(user)` | Get user's TR threshold | View |
| `carMinBpsOf(user)` | Get user's CAR minimum | View |
| `isWhitelisted(user)` | Check if user is active and KYC'd | View |

### DualPoR

| Function | Description | Access |
|----------|-------------|--------|
| `ratioBps()` | Get conservative minimum PoR ratio | View |
| `requireAbove(minBps)` | Check if ratio meets minimum | View |
| `checkDivergence()` | Check divergence and emit alert | Public |

### MonthlyDigest

| Function | Description | Access |
|----------|-------------|--------|
| `pin(yyyymm, root, cidHash)` | Pin monthly audit digest | Public |
| `rootForMonth(yyyymm)` | Get Merkle root for month | View |
| `cidForMonth(yyyymm)` | Get CID hash for month | View |

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass: `forge test`
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

- Built with [Foundry](https://github.com/foundry-rs/foundry)
- Post-quantum cryptography research from [NIST PQC](https://csrc.nist.gov/projects/post-quantum-cryptography)
- Travel Rule compliance standards from [FATF](https://www.fatf-gafi.org/)

---

**⚠️ Disclaimer**: This code is provided as-is for educational and development purposes. Always conduct thorough security audits before deploying to mainnet.
