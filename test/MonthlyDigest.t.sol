// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/Test.sol";
import {MonthlyDigest} from "../contracts/audit/MonthlyDigest.sol";

contract MonthlyDigestTest is Test {
    function test_PinOnce() public {
        MonthlyDigest d = new MonthlyDigest();
        d.pin(202510, keccak256("root"), keccak256(bytes("ipfs://cid")));
        vm.expectRevert(MonthlyDigest.AlreadyPinned.selector);
        d.pin(202510, keccak256("root"), keccak256(bytes("ipfs://cid")));
    }
}
