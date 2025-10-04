// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IComplianceRegistryExtended} from "./interfaces/IComplianceRegistryExtended.sol";
import {ITravelRuleRegistry} from "./interfaces/ITravelRuleRegistry.sol";
import {IProofOfReserves} from "./interfaces/IProofOfReserves.sol";

contract TGUSD {
    mapping(address=>uint256) public balanceOf;
    uint256 public totalSupply;

    // registries/oracles
    IComplianceRegistryExtended public COMP;
    address public TR;
    address public POR;

    bool public paused;
    mapping(bytes32=>bool) public trUsed;

    // --- Admin wiring for tests ---
    function __testSetCompliance(address c) external { COMP = IComplianceRegistryExtended(c); }
    function __testSetTR(address t) external { TR = t; }
    function __testSetPoR(address p) external { POR = p; }
    function __mint(address to, uint256 amt) external { _mint(to, amt); }

    // --- Business logic ---
    modifier pqAndKyc(address u, bytes32, bytes32, bytes32) {
        // minimal: require profile active and KYC != NONE
        require(COMP.isWhitelisted(u), "KYC");
        _;
    }

    function setComplianceRegistry(address c) external { COMP = IComplianceRegistryExtended(c); }

    function transferLarge(address to, uint256 amt, bytes32 sessionId) external returns (bool) {
        require(!paused, "PAUSED");
        uint96 thr = COMP.travelRuleThresholdOf(msg.sender);
        if (amt >= thr) {
            require(ITravelRuleRegistry(TR).exists(sessionId), "TR_MISSING");
            require(!trUsed[sessionId], "TR_USED");
            trUsed[sessionId] = true;
        }
        _transfer(msg.sender, to, amt);
        return true;
    }

    function mintWithPQ(address to, uint256 amt, bytes32 msgH, bytes32 pkH, bytes32 sigH)
        external pqAndKyc(msg.sender, msgH, pkH, sigH)
    {
        // active divergence check (best-effort)
        (bool ok, ) = POR.call(abi.encodeWithSignature("checkDivergence()"));
        if (!ok) { paused = true; revert("POR_DIV"); }

        uint32 carMin = COMP.carMinBpsOf(msg.sender);
        require(IProofOfReserves(POR).requireAbove(carMin), "POR<CAR_MIN");
        _mint(to, amt);
    }

    // --- internals ---
    function _transfer(address from, address to, uint256 amt) internal {
        require(balanceOf[from] >= amt, "BAL");
        unchecked {
            balanceOf[from] -= amt;
            balanceOf[to] += amt;
        }
    }
    function _mint(address to, uint256 amt) internal {
        totalSupply += amt;
        balanceOf[to] += amt;
    }
}
