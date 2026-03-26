// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/L28Token.sol";
import "../src/L28PlusToken.sol";
import "../src/SubToken.sol";
import "../src/SubTokenFactory.sol";
import "../src/ComplianceOracle.sol";
import "../src/EscrowOracle.sol";
import "../src/GovernanceRegistry.sol";
import "../src/AssetOracle.sol";
import "./mocks/MockV3Aggregator.sol";

contract L28EcosystemTest is Test {
    L28Token public l28;
    L28PlusToken public l28Plus;
    SubTokenFactory public factory;
    ComplianceOracle public compliance;
    EscrowOracle public escrow;
    GovernanceRegistry public governance;
    AssetOracle public assetOracle;

    address public admin = address(0xAD);
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    bytes32 public identityHash1 = keccak256("Identity1");
    bytes32 public identityHash2 = keccak256("Identity2");
    bytes32 public projectId = keccak256("Project1");

    function setUp() public {
        vm.startPrank(admin);
        
        compliance = new ComplianceOracle();
        escrow = new EscrowOracle();
        governance = new GovernanceRegistry();
        
        l28 = new L28Token(address(compliance), address(escrow));
        l28Plus = new L28PlusToken();
        factory = new SubTokenFactory(address(governance), address(compliance), address(escrow));
        assetOracle = new AssetOracle();

        // Grant roles/authorizations
        compliance.setAuthorizedCaller(admin, true);
        escrow.setAuthorizedCaller(admin, true);
        escrow.setAuthorizedCaller(address(l28), true); // Authorize L28Token for minting
        governance.setCommitteeMember(admin, true);
        governance.setCommitteeMember(user2, true); // Create a second committee member

        vm.stopPrank();
    }

    function test_IdentityWrappedMint() public {
        vm.startPrank(admin);

        // 1. Set up compliance for user1
        compliance.setComplianceStatus(user1, ComplianceOracle.ComplianceStatus.APPROVED, identityHash1);
        
        // 2. Confirm escrow for user1
        bytes32 escrowId = keccak256("Escrow1");
        escrow.confirmEscrow(escrowId, 1000e18, keccak256("DepositRef1"));

        // 3. Mint L28
        l28.mint(user1, 1000e18, escrowId);

        vm.stopPrank();

        assertEq(l28.balanceOf(user1), 1000e18);
        
        // 4. Verify identity wrapping
        L28Token.TokenMetadata memory meta = l28.getMetadata(user1);
        assertEq(meta.escrowId, escrowId);
        assertEq(meta.identityHash, identityHash1);
    }

    function test_ComplianceGatedTransfer() public {
        vm.startPrank(admin);
        compliance.setComplianceStatus(user1, ComplianceOracle.ComplianceStatus.APPROVED, identityHash1);
        bytes32 escrowId = keccak256("Escrow1");
        escrow.confirmEscrow(escrowId, 1000e18, keccak256("DepositRef1"));
        l28.mint(user1, 1000e18, escrowId);
        vm.stopPrank();

        // user1 (approved) tries to send to user2 (not approved)
        vm.prank(user1);
        vm.expectRevert("Receiver compliance check failed");
        l28.transfer(user2, 500e18);
    }

    function test_L28PlusNonTransferable() public {
        vm.prank(admin);
        l28Plus.mint(user1, 100e18);

        vm.prank(user1);
        vm.expectRevert("L28+: Transfers not permitted");
        l28Plus.transfer(user2, 50e18);
    }

    function test_SubTokenConcentrationLimit() public {
        vm.startPrank(admin);
        
        compliance.setComplianceStatus(user1, ComplianceOracle.ComplianceStatus.APPROVED, identityHash1);
        compliance.setComplianceStatus(user2, ComplianceOracle.ComplianceStatus.APPROVED, identityHash2);
        
        governance.approveProject(projectId); // First approval (admin)
        
        vm.prank(user2);
        governance.approveProject(projectId); // Second approval (user2)
        
        address subTokenAddr = factory.deploySubToken("Project A", "PRJ-A", projectId, 1_000_000e18);
        SubToken subToken = SubToken(subTokenAddr);
        
        // Authorize SubToken for minting
        escrow.setAuthorizedCaller(subTokenAddr, true);

        // Minting to user1 within 20% limit (200,000)
        bytes32 escrow1 = keccak256("SubEscrow1");
        escrow.confirmEscrow(escrow1, 200_000e18, keccak256("Ref1"));
        subToken.mint(user1, 200_000e18, escrow1);
        
        assertEq(subToken.balanceOf(user1), 200_000e18);

        // Try to mint more to exceed 20% limit
        bytes32 escrow2 = keccak256("SubEscrow2");
        escrow.confirmEscrow(escrow2, 1e18, keccak256("Ref2"));
        
        vm.expectRevert("Concentration limit exceeded (20%)");
        subToken.mint(user1, 1e18, escrow2);

        vm.stopPrank();
    }

    function test_NavCalculationWithChainlink() public {
        vm.startPrank(admin);
        
        // 10 AED per unit (8 decimals common for USD/AED)
        MockV3Aggregator mockAggregator = new MockV3Aggregator(8, 10e8);
        
        // Project with 10k units (sq ft) and 2k AED liabilities
        assetOracle.updateAssetConfig(projectId, address(mockAggregator), 10_000, 2000e8);
        
        // Total supply of tokens is 100k
        uint256 totalSupply = 100_000e18;
        
        // NAV = (10,000 * 10 - 2,000) / 100,000 = 80,000 / 100,000 = 0.8 per token
        uint256 nav = assetOracle.calculateNAV(projectId, totalSupply);
        
        assertEq(nav, (100_000e8 - 2000e8) / 100_000); // 0.98e8 maybe? wait
        // wait math: (10,000 * 10e8 - 2000e8) = 100,000e8 - 2000e8 = 98,000e8
        // 98,000e8 / 100,000 = 0.98e8
        
        vm.stopPrank();
    }
}
