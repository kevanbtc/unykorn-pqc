// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/Test.sol";
import {TGUSD} from "../contracts/TGUSD.sol";
import {ComplianceRegistry} from "../contracts/compliance/ComplianceRegistry.sol";
import {IProofOfReserves} from "../contracts/interfaces/IProofOfReserves.sol";
import {ITravelRuleRegistry, TravelRuleProof} from "../contracts/interfaces/ITravelRuleRegistry.sol";
import {IComplianceRegistryExtended} from "../contracts/interfaces/IComplianceRegistryExtended.sol";

contract PoRMock2 is IProofOfReserves { uint256 r; function set(uint v) external { r=v; } function ratioBps() external view returns (uint256){return r;} function requireAbove(uint256 m) external view returns(bool){return r>=m;} function checkDivergence() external pure returns (bool){ return true; } }
contract TRMock2 is ITravelRuleRegistry { mapping(bytes32=>bool) ex; function record(TravelRuleProof calldata p) external { ex[p.sessionId]=true; } function exists(bytes32 sid) external view returns(bool){return ex[sid]; } function seed(bytes32 s) external { ex[s]=true; } }

contract Jurisdiction_Thresholds is Test {
    TGUSD g; ComplianceRegistry comp; PoRMock2 por; TRMock2 tr;

    function setUp() public {
        g = new TGUSD(); comp = new ComplianceRegistry(); por = new PoRMock2(); tr = new TRMock2();
        g.__testSetCompliance(address(comp));
        g.__testSetPoR(address(por));
        g.__testSetTR(address(tr));
        // seed profile: US sender
        IComplianceRegistryExtended.ComplianceProfile memory p = IComplianceRegistryExtended.ComplianceProfile({
            active:true,
            j:IComplianceRegistryExtended.Jurisdiction.US,
            kyc:IComplianceRegistryExtended.KYCStatus.BASIC,
            risk:IComplianceRegistryExtended.RiskTier.LOW,
            acc:IComplianceRegistryExtended.AccLevel.NONE,
            pep:false,
            lockupEnd:0,
            dailyLimit:type(uint96).max,
            outstanding24h:0,
            pqPkHash:bytes32(0)
        });
        comp.setProfile(address(this), p);
        por.set(13000);
        g.__mint(address(this), 10_000e6);
    }

    function test_TR_US_3000() public {
        bytes32 sid = keccak256("us");
        vm.expectRevert(bytes("TR_MISSING"));
        g.transferLarge(address(0xBEEF), 3_000e6, sid);
        tr.seed(sid);
        g.transferLarge(address(0xBEEF), 3_000e6, sid);
    }

    function test_PoR_CAR_Min_Respected() public {
        // US carMin=12000
        por.set(11999);
        (bool ok,) = address(g).call(abi.encodeWithSignature("mintWithPQ(address,uint256,bytes32,bytes32,bytes32)", address(this), 1, bytes32(0), bytes32(0), bytes32(0)));
        assertTrue(!ok, "PoR below US carMin must fail");
        por.set(12000);
        (bool ok2,) = address(g).call(abi.encodeWithSignature("mintWithPQ(address,uint256,bytes32,bytes32,bytes32)", address(this), 1, bytes32(0), bytes32(0), bytes32(0)));
        assertTrue(ok2, "PoR at carMin should pass");
    }
}
