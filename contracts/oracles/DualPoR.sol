// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IProofOfReserves} from "../interfaces/IProofOfReserves.sol";

contract DualPoR is IProofOfReserves {
    IProofOfReserves public primary;
    IProofOfReserves public backup;
    uint32 public maxDivergenceBps; // e.g., 100 = 1%
    event DivergenceAlert(uint256 p, uint256 b, uint256 diffBps, uint40 ts);

    constructor(address _p, address _b, uint32 _maxDivBps) {
        primary = IProofOfReserves(_p); backup = IProofOfReserves(_b); maxDivergenceBps = _maxDivBps;
    }

    function ratioBps() public view returns (uint256) {
        uint256 rp = primary.ratioBps();
        uint256 rb = backup.ratioBps();
        uint256 diff = rp>rb ? rp-rb : rb-rp;
        uint256 denom = ((rp+rb)/2);
        uint256 diffBps = (diff * 10_000) / (denom == 0 ? 1 : denom);
        if (diffBps > maxDivergenceBps) {
            // view function: cannot emit here; use checkDivergence in tx paths
        }
        return rp < rb ? rp : rb; // conservative
    }

    function requireAbove(uint256 minBps) external view returns (bool) {
        return ratioBps() >= minBps;
    }

    // helper (tx path) to surface alert
    function checkDivergence() external returns (bool ok) {
        uint256 rp = primary.ratioBps(); uint256 rb = backup.ratioBps();
        uint256 diff = rp>rb ? rp-rb : rb-rp;
        uint256 denom = ((rp+rb)/2);
        uint256 diffBps = (diff * 10_000) / (denom == 0 ? 1 : denom);
        ok = diffBps <= maxDivergenceBps;
        if (!ok) emit DivergenceAlert(rp, rb, diffBps, uint40(block.timestamp));
    }
}
