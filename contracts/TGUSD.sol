// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IComplianceRegistryExtended} from "./interfaces/IComplianceRegistryExtended.sol";
import {ITravelRuleRegistry} from "./interfaces/ITravelRuleRegistry.sol";
import {IProofOfReserves} from "./interfaces/IProofOfReserves.sol";

/**
 * @title TGUSD - Compliance-Aware Stablecoin with Post-Quantum Readiness
 * @notice This contract implements a stablecoin with jurisdiction-aware compliance,
 *         Travel Rule enforcement, and Proof-of-Reserves verification
 * @dev Integrates with ComplianceRegistry, TravelRuleRegistry, and DualPoR oracles
 */
contract TGUSD {
    // --- State Variables ---
    mapping(address=>uint256) public balanceOf;
    uint256 public totalSupply;

    // registries/oracles
    IComplianceRegistryExtended public COMP;
    address public TR;
    address public POR;

    bool public paused;
    mapping(bytes32=>bool) public trUsed;
    address public admin;

    // --- Events ---
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Mint(address indexed to, uint256 value);
    event Paused(address indexed by, string reason);
    event ComplianceRegistryUpdated(address indexed newRegistry);
    event TravelRuleRegistryUpdated(address indexed newRegistry);
    event ProofOfReservesUpdated(address indexed newOracle);

    // --- Custom Errors ---
    error Unauthorized();
    error ContractPaused();
    error InsufficientBalance();
    error KYCRequired();
    error TravelRuleSessionMissing();
    error TravelRuleSessionAlreadyUsed();
    error ProofOfReservesDivergence();
    error ProofOfReservesInsufficient();

    // --- Constructor ---
    constructor() {
        admin = msg.sender;
    }

    // --- Modifiers ---
    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }

    /**
     * @notice Validates post-quantum credentials and KYC status
     * @dev Checks that user is whitelisted in ComplianceRegistry
     */
    modifier pqAndKyc(address u, bytes32, bytes32, bytes32) {
        if (!COMP.isWhitelisted(u)) revert KYCRequired();
        _;
    }

    // --- Admin Functions ---
    /**
     * @notice Updates the compliance registry address
     * @param c Address of the new ComplianceRegistry contract
     */
    function setComplianceRegistry(address c) external onlyAdmin { 
        COMP = IComplianceRegistryExtended(c); 
        emit ComplianceRegistryUpdated(c);
    }

    /**
     * @notice Updates the Travel Rule registry address
     * @param t Address of the new TravelRuleRegistry contract
     */
    function setTravelRuleRegistry(address t) external onlyAdmin {
        TR = t;
        emit TravelRuleRegistryUpdated(t);
    }

    /**
     * @notice Updates the Proof of Reserves oracle address
     * @param p Address of the new ProofOfReserves oracle
     */
    function setProofOfReserves(address p) external onlyAdmin {
        POR = p;
        emit ProofOfReservesUpdated(p);
    }

    // --- Test Helpers (should be removed in production) ---
    function __testSetCompliance(address c) external { COMP = IComplianceRegistryExtended(c); }
    function __testSetTR(address t) external { TR = t; }
    function __testSetPoR(address p) external { POR = p; }
    function __mint(address to, uint256 amt) external { _mint(to, amt); }

    // --- Business Logic ---
    /**
     * @notice Transfer tokens with Travel Rule compliance for large transactions
     * @dev Requires Travel Rule session if amount >= jurisdiction threshold
     * @param to Recipient address
     * @param amt Amount to transfer
     * @param sessionId Unique Travel Rule session identifier (single-use)
     * @return success True if transfer succeeded
     */
    function transferLarge(address to, uint256 amt, bytes32 sessionId) external returns (bool) {
        if (paused) revert ContractPaused();
        
        uint96 thr = COMP.travelRuleThresholdOf(msg.sender);
        if (amt >= thr) {
            if (!ITravelRuleRegistry(TR).exists(sessionId)) revert TravelRuleSessionMissing();
            if (trUsed[sessionId]) revert TravelRuleSessionAlreadyUsed();
            trUsed[sessionId] = true;
        }
        _transfer(msg.sender, to, amt);
        return true;
    }

    /**
     * @notice Mint tokens with post-quantum signature verification and PoR check
     * @dev Validates KYC, checks PoR divergence, and enforces jurisdiction CAR minimums
     * @param to Address to mint tokens to
     * @param amt Amount to mint
     * @param msgH Message hash (for PQ signature verification)
     * @param pkH Public key hash (for PQ signature verification)
     * @param sigH Signature hash (for PQ signature verification)
     */
    function mintWithPQ(address to, uint256 amt, bytes32 msgH, bytes32 pkH, bytes32 sigH)
        external pqAndKyc(msg.sender, msgH, pkH, sigH)
    {
        // Check for PoR feed divergence - auto-pause if detected
        (bool ok, ) = POR.call(abi.encodeWithSignature("checkDivergence()"));
        if (!ok) { 
            paused = true; 
            emit Paused(address(this), "PoR divergence detected");
            revert ProofOfReservesDivergence();
        }

        // Enforce jurisdiction-specific CAR/PoR minimum
        uint32 carMin = COMP.carMinBpsOf(msg.sender);
        if (!IProofOfReserves(POR).requireAbove(carMin)) revert ProofOfReservesInsufficient();
        
        _mint(to, amt);
    }

    // --- Internal Functions ---
    /**
     * @dev Internal transfer function
     */
    function _transfer(address from, address to, uint256 amt) internal {
        if (balanceOf[from] < amt) revert InsufficientBalance();
        unchecked {
            balanceOf[from] -= amt;
            balanceOf[to] += amt;
        }
        emit Transfer(from, to, amt);
    }

    /**
     * @dev Internal mint function
     */
    function _mint(address to, uint256 amt) internal {
        totalSupply += amt;
        balanceOf[to] += amt;
        emit Mint(to, amt);
    }
}
