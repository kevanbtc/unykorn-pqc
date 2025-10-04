// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/Test.sol";
import {DualPoR} from "../contracts/oracles/DualPoR.sol";
import {IProofOfReserves} from "../contracts/interfaces/IProofOfReserves.sol";

contract PorMock is IProofOfReserves {
    uint256 r; function set(uint v) external { r=v; }
    function ratioBps() external view returns(uint256){ return r; }
    function requireAbove(uint256 m) external view returns(bool){ return r>=m; }
}

contract DualPoR_Divergence is Test {
    PorMock a; PorMock b; DualPoR d;
    function setUp() public { a=new PorMock(); b=new PorMock(); a.set(12500); b.set(12450); d=new DualPoR(address(a),address(b),100); }

    function test_ConservativeMin() public {
        assertEq(d.ratioBps(), 12450); // min of the two
    }

    function test_AlertOnDivergence() public {
        a.set(14000); b.set(12000); // ~15% diff
        bool ok = d.checkDivergence();
        assertTrue(!ok, "should alert/diverge");
    }
}
