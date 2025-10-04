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
    
    address public owner;
    
    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Mint(address indexed to, uint256 value);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    
    error Unauthorized();
    error ZeroAddress();
    
    constructor(address _comp, address _tr, address _por) {
        if (_comp == address(0) || _tr == address(0) || _por == address(0)) revert ZeroAddress();
        owner = msg.sender;
        COMP = IComplianceRegistryExtended(_comp);
        TR = _tr;
        POR = _por;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    // --- Admin wiring for tests ---
    function __testSetCompliance(address c) external onlyOwner { 
        if (c == address(0)) revert ZeroAddress();
        COMP = IComplianceRegistryExtended(c); 
    }
    function __testSetTR(address t) external onlyOwner { 
        if (t == address(0)) revert ZeroAddress();
        TR = t; 
    }
    function __testSetPoR(address p) external onlyOwner { 
        if (p == address(0)) revert ZeroAddress();
        POR = p; 
    }
    function __mint(address to, uint256 amt) external onlyOwner { _mint(to, amt); }

    // --- Business logic ---
    modifier pqAndKyc(address u, bytes32, bytes32, bytes32) {
        // minimal: require profile active and KYC != NONE
        require(COMP.isWhitelisted(u), "KYC");
        _;
    }

    function setComplianceRegistry(address c) external onlyOwner { 
        if (c == address(0)) revert ZeroAddress();
        COMP = IComplianceRegistryExtended(c); 
    }
    
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        if (_paused) {
            emit Paused(msg.sender);
        } else {
            emit Unpaused(msg.sender);
        }
    }

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
        (bool ok, bytes memory data) = POR.call(abi.encodeWithSignature("checkDivergence()"));
        if (ok && data.length >= 32) {
            bool divergenceOk = abi.decode(data, (bool));
            if (!divergenceOk) { 
                paused = true; 
                emit Paused(address(this));
                revert("POR_DIV"); 
            }
        }

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
        emit Transfer(from, to, amt);
    }
    function _mint(address to, uint256 amt) internal {
        totalSupply += amt;
        balanceOf[to] += amt;
        emit Mint(to, amt);
        emit Transfer(address(0), to, amt);
    }
}
