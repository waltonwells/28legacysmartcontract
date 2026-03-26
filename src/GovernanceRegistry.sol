// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GovernanceRegistry
 * @notice On-chain record of governance approvals for project listings.
 * @dev Enforces dual-approval from authorized committee members.
 */
contract GovernanceRegistry is Ownable {
    struct ProjectListing {
        bool activated;
        uint8 approvalCount;
        mapping(address => bool) approvals;
        uint256 activationTimestamp;
    }

    // Mapping from projectId to listing record
    mapping(bytes32 => ProjectListing) private projectListings;

    // Authorized governance committee members
    mapping(address => bool) public isCommitteeMember;

    event ProjectApproved(bytes32 indexed projectId, address indexed approver);
    event ProjectActivated(bytes32 indexed projectId);
    event CommitteeMemberUpdated(address indexed member, bool authorized);

    modifier onlyCommittee() {
        require(isCommitteeMember[msg.sender], "Not a committee member");
        _;
    }

    constructor() Ownable(msg.sender) {}

    function setCommitteeMember(address member, bool authorized) external onlyOwner {
        isCommitteeMember[member] = authorized;
        emit CommitteeMemberUpdated(member, authorized);
    }

    /**
     * @notice Submits a governance approval for a project listing.
     * @dev Two unique committee members must approve before activation.
     * @param projectId Unique identifier of the project.
     */
    function approveProject(bytes32 projectId) external onlyCommittee {
        ProjectListing storage listing = projectListings[projectId];
        require(!listing.activated, "Project already activated");
        require(!listing.approvals[msg.sender], "Already approved by this member");

        listing.approvals[msg.sender] = true;
        listing.approvalCount++;

        emit ProjectApproved(projectId, msg.sender);

        if (listing.approvalCount >= 2) {
            listing.activated = true;
            listing.activationTimestamp = block.timestamp;
            emit ProjectActivated(projectId);
        }
    }

    /**
     * @notice Checks if a project listing is activated through dual approval.
     */
    function isActivated(bytes32 projectId) external view returns (bool) {
        return projectListings[projectId].activated;
    }

    /**
     * @notice Returns the number of approvals for a project.
     */
    function getApprovalCount(bytes32 projectId) external view returns (uint8) {
        return projectListings[projectId].approvalCount;
    }
}
