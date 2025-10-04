// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/Test.sol";
import {TGUSD} from "../contracts/TGUSD.sol";
import {ComplianceRegistry} from "../contracts/compliance/ComplianceRegistry.sol";
import {IProofOfReserves} from "../contracts/interfaces/IProofOfReserves.sol";
import {ITravelRuleRegistry, TravelRuleProof} from "../contracts/interfaces/ITravelRuleRegistry.sol";
import {IComplianceRegistryExtended} from "../contracts/interfaces/IComplianceRegistryExtended.sol";

contract PoRMock3 is IProofOfReserves { 
    uint256 r; 
    function set(uint v) external { r=v; } 
    function ratioBps() external view returns (uint256){return r;} 
    function requireAbove(uint256 m) external view returns(bool){return r>=m;} 
    function checkDivergence() external pure returns (bool){ return true; } 
}

contract TRMock3 is ITravelRuleRegistry { 
    mapping(bytes32=>bool) ex; 
    function record(TravelRuleProof calldata p) external { ex[p.sessionId]=true; } 
    function exists(bytes32 sid) external view returns(bool){return ex[sid]; } 
    function seed(bytes32 s) external { ex[s]=true; } 
}

contract TGUSD_SecurityFixes is Test {
    TGUSD g;
    ComplianceRegistry comp;
    PoRMock3 por;
    TRMock3 tr;
    address user1 = address(0x1);
    address user2 = address(0x2);

    function setUp() public {
        comp = new ComplianceRegistry();
        por = new PoRMock3();
        tr = new TRMock3();
        g = new TGUSD(address(comp), address(tr), address(por));
        
        // Setup user profile
        IComplianceRegistryExtended.ComplianceProfile memory p = IComplianceRegistryExtended.ComplianceProfile({
            active: true,
            j: IComplianceRegistryExtended.Jurisdiction.US,
            kyc: IComplianceRegistryExtended.KYCStatus.BASIC,
            risk: IComplianceRegistryExtended.RiskTier.LOW,
            acc: IComplianceRegistryExtended.AccLevel.NONE,
            pep: false,
            lockupEnd: 0,
            dailyLimit: type(uint96).max,
            outstanding24h: 0,
            pqPkHash: bytes32(0)
        });
        comp.setProfile(address(this), p);
        por.set(13000);
    }

    function test_ConstructorValidation() public {
        // Should revert with zero addresses
        vm.expectRevert(TGUSD.ZeroAddress.selector);
        new TGUSD(address(0), address(tr), address(por));
        
        vm.expectRevert(TGUSD.ZeroAddress.selector);
        new TGUSD(address(comp), address(0), address(por));
        
        vm.expectRevert(TGUSD.ZeroAddress.selector);
        new TGUSD(address(comp), address(tr), address(0));
    }

    function test_OnlyOwnerCanSetCompliance() public {
        ComplianceRegistry newComp = new ComplianceRegistry();
        
        // Owner can set
        g.setComplianceRegistry(address(newComp));
        assertEq(address(g.COMP()), address(newComp));
        
        // Non-owner cannot set
        vm.prank(user1);
        vm.expectRevert(TGUSD.Unauthorized.selector);
        g.setComplianceRegistry(address(comp));
    }

    function test_OnlyOwnerCanPause() public {
        // Owner can pause
        assertFalse(g.paused());
        g.setPaused(true);
        assertTrue(g.paused());
        
        // Non-owner cannot pause
        vm.prank(user1);
        vm.expectRevert(TGUSD.Unauthorized.selector);
        g.setPaused(false);
    }

    function test_CanUnpause() public {
        // Pause the contract
        g.setPaused(true);
        assertTrue(g.paused());
        
        // Unpause the contract
        g.setPaused(false);
        assertFalse(g.paused());
    }

    function test_TransferEmitsEvent() public {
        g.__mint(address(this), 1000e6);
        
        vm.expectEmit(true, true, false, true);
        emit TGUSD.Transfer(address(this), user1, 100e6);
        
        bytes32 sid = keccak256("session");
        tr.seed(sid);
        g.transferLarge(user1, 100e6, sid);
    }

    function test_MintEmitsEvents() public {
        vm.expectEmit(true, false, false, true);
        emit TGUSD.Mint(address(this), 100e6);
        
        vm.expectEmit(true, true, false, true);
        emit TGUSD.Transfer(address(0), address(this), 100e6);
        
        g.__mint(address(this), 100e6);
    }

    function test_PausedEventEmitted() public {
        vm.expectEmit(true, false, false, false);
        emit TGUSD.Paused(address(this));
        g.setPaused(true);
    }

    function test_UnpausedEventEmitted() public {
        g.setPaused(true);
        
        vm.expectEmit(true, false, false, false);
        emit TGUSD.Unpaused(address(this));
        g.setPaused(false);
    }

    function test_ZeroAddressValidationOnSet() public {
        vm.expectRevert(TGUSD.ZeroAddress.selector);
        g.setComplianceRegistry(address(0));
        
        vm.expectRevert(TGUSD.ZeroAddress.selector);
        g.__testSetCompliance(address(0));
        
        vm.expectRevert(TGUSD.ZeroAddress.selector);
        g.__testSetTR(address(0));
        
        vm.expectRevert(TGUSD.ZeroAddress.selector);
        g.__testSetPoR(address(0));
    }

    function test_OnlyOwnerCanMint() public {
        // Owner can mint
        g.__mint(address(this), 100e6);
        assertEq(g.balanceOf(address(this)), 100e6);
        
        // Non-owner cannot mint
        vm.prank(user1);
        vm.expectRevert(TGUSD.Unauthorized.selector);
        g.__mint(user1, 100e6);
    }
}
