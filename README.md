# Unykorn PQC

This repo includes drop-in pillars for compliance-aware, PQC-ready tokens:

- Jurisdiction-aware thresholds (Travel Rule + CAR/PoR)
- Monthly audit anchors (digest)
- Dual Proof-of-Reserves (PoR) oracles with divergence auto-pause

## Jurisdiction profiles → dynamic thresholds

The `ComplianceRegistry` stores per-user profiles and jurisdiction policies:

- travelRuleThresholdOf(user): returns the sender’s Travel Rule threshold in base units
- carMinBpsOf(user): returns the jurisdiction’s minimum PoR/CAR requirement in basis points

TGUSD uses these in:

- transferLarge(to, amt, sessionId): requires a Travel Rule session if amt >= threshold; session is single-use
- mintWithPQ(to, amt, msgH, pkH, sigH): requires PoR >= jurisdiction minimum

Admin API (example):

- setProfile(user, profile)
- setJurisdictionPolicy(jurisdiction, trThreshold, carMinBps)

## Monthly audit anchors (digest)

`MonthlyDigest` pins a single (root, cidHash) per month. Attempting to repin same yyyymm reverts.

Operational note: a CI/cron job aggregates daily ledger roots into a monthly JSON blob, pins to IPFS, and calls `pin(yyyymm, root, keccak256(cid))`.

## Dual PoR with divergence guard

`DualPoR` wraps two PoR feeds. It returns the conservative minimum ratio and emits `DivergenceAlert` if the feeds diverge beyond `maxDivergenceBps` when `checkDivergence()` is called on-chain. TGUSD calls `checkDivergence()` in `mintWithPQ` and auto-pauses if divergence is detected.

## Quick run

Run the focused tests:

```powershell
forge test --match-path test/Jurisdiction_Thresholds.t.sol -vv
forge test --match-path test/MonthlyDigest.t.sol -vv
forge test --match-path test/DualPoR_Divergence.t.sol -vv
```
