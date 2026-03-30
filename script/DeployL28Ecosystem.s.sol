// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ComplianceOracle} from "../src/ComplianceOracle.sol";
import {EscrowOracle} from "../src/EscrowOracle.sol";
import {GovernanceRegistry} from "../src/GovernanceRegistry.sol";
import {L28Token} from "../src/L28Token.sol";
import {L28PlusToken} from "../src/L28PlusToken.sol";
import {SubTokenFactory} from "../src/SubTokenFactory.sol";
import {AssetOracle} from "../src/AssetOracle.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy ComplianceOracle (no constructor args)
        ComplianceOracle complianceOracle = new ComplianceOracle();

        // 2. Deploy EscrowOracle (no constructor args)
        EscrowOracle escrowOracle = new EscrowOracle();

        // 3. Deploy GovernanceRegistry (no constructor args)
        GovernanceRegistry governanceRegistry = new GovernanceRegistry();

        // 4. Deploy L28Token (depends on ComplianceOracle and EscrowOracle)
        L28Token l28Token = new L28Token(address(complianceOracle), address(escrowOracle));

        // 5. Deploy L28PlusToken (no constructor args)
        L28PlusToken l28PlusToken = new L28PlusToken();

        // 6. Deploy SubTokenFactory (depends on GovernanceRegistry, ComplianceOracle, EscrowOracle)
        SubTokenFactory subTokenFactory = new SubTokenFactory(
            address(governanceRegistry),
            address(complianceOracle),
            address(escrowOracle)
        );

        // 7. Deploy AssetOracle (no constructor args)
        AssetOracle assetOracle = new AssetOracle();

        // Post-deployment: authorize deployer on ComplianceOracle
        complianceOracle.setAuthorizedCaller(deployer, true);

        // Post-deployment: authorize deployer on EscrowOracle
        escrowOracle.setAuthorizedCaller(deployer, true);

        // Post-deployment: authorize L28Token to call consumeEscrow during minting
        escrowOracle.setAuthorizedCaller(address(l28Token), true);

        // Post-deployment: set deployer as committee member on GovernanceRegistry
        governanceRegistry.setCommitteeMember(deployer, true);

        vm.stopBroadcast();

        // Log all addresses in KEY=address format for easy .env copy-paste
        console.log("COMPLIANCE_ORACLE_ADDRESS=%s", address(complianceOracle));
        console.log("ESCROW_ORACLE_ADDRESS=%s", address(escrowOracle));
        console.log("GOVERNANCE_REGISTRY_ADDRESS=%s", address(governanceRegistry));
        console.log("L28_TOKEN_ADDRESS=%s", address(l28Token));
        console.log("L28_PLUS_TOKEN_ADDRESS=%s", address(l28PlusToken));
        console.log("SUBTOKEN_FACTORY_ADDRESS=%s", address(subTokenFactory));
        console.log("ASSET_ORACLE_ADDRESS=%s", address(assetOracle));
    }
}
