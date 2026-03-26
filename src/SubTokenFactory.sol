// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./SubToken.sol";
import "./GovernanceRegistry.sol";

/**
 * @title SubTokenFactory
 * @notice Factory for deploying project-specific SubToken contracts.
 * @dev Restricted to governance/admin roles.
 */
contract SubTokenFactory is Ownable {
    GovernanceRegistry public immutable governanceRegistry;
    address public immutable complianceOracle;
    address public immutable escrowOracle;

    // Mapping from projectId to SubToken contract address
    mapping(bytes32 => address) public projectSubTokens;

    event SubTokenDeployed(bytes32 indexed projectId, address indexed subTokenAddress);

    constructor(
        address _governanceRegistry,
        address _complianceOracle,
        address _escrowOracle
    ) Ownable(msg.sender) {
        governanceRegistry = GovernanceRegistry(_governanceRegistry);
        complianceOracle = _complianceOracle;
        escrowOracle = _escrowOracle;
    }

    /**
     * @notice Deploys a new SubToken contract for an approved project.
     */
    function deploySubToken(
        string memory name,
        string memory symbol,
        bytes32 projectId,
        uint256 maxSupply
    ) external onlyOwner returns (address) {
        require(governanceRegistry.isActivated(projectId), "Project not activated by governance");
        require(projectSubTokens[projectId] == address(0), "SubToken already exists for this project");

        SubToken newToken = new SubToken(
            name,
            symbol,
            projectId,
            maxSupply,
            complianceOracle,
            escrowOracle
        );

        projectSubTokens[projectId] = address(newToken);
        emit SubTokenDeployed(projectId, address(newToken));

        return address(newToken);
    }

    /**
     * @notice Returns the SubToken address for a given project.
     */
    function getSubToken(bytes32 projectId) external view returns (address) {
        return projectSubTokens[projectId];
    }
}
