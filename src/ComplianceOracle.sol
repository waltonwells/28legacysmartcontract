// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ComplianceOracle
 * @notice On-chain registry for KYC/KYB and AML status updates.
 * @dev Managed by the Identity and Compliance service layer.
 */
contract ComplianceOracle is Ownable {
    enum ComplianceStatus { NONE, PENDING, APPROVED, SUSPENDED, EXPIRED, AML_FLAG }

    struct IdentityRecord {
        ComplianceStatus status;
        bytes32 identityHash; // Cryptographic hash of off-chain records
        uint256 lastUpdated;
    }

    // Mapping from wallet address to identity record
    mapping(address => IdentityRecord) public identityRecords;
    
    // Mapping from identity hash to list of linked wallets (for concentration limits)
    mapping(bytes32 => address[]) public identityWallets;

    // Authorized service wallets (Identity Service)
    mapping(address => bool) public authorizedCallers;

    event ComplianceStatusUpdated(address indexed wallet, ComplianceStatus status, bytes32 identityHash);
    event CallerAuthorizationUpdated(address indexed caller, bool authorized);

    modifier onlyAuthorized() {
        require(owner() == msg.sender || authorizedCallers[msg.sender], "Not authorized");
        _;
    }

    constructor() Ownable(msg.sender) {}

    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        authorizedCallers[caller] = authorized;
        emit CallerAuthorizationUpdated(caller, authorized);
    }

    /**
     * @notice Updates the compliance status of a wallet.
     * @param wallet The address to update.
     * @param status The new compliance status.
     * @param identityHash Hash of the off-chain identity/document records.
     */
    function setComplianceStatus(
        address wallet,
        ComplianceStatus status,
        bytes32 identityHash
    ) external onlyAuthorized {
        IdentityRecord storage record = identityRecords[wallet];
        
        // If assigning a new identity hash, update the identityWallets mapping
        if (record.identityHash != identityHash && identityHash != bytes32(0)) {
            identityWallets[identityHash].push(wallet);
        }

        record.status = status;
        record.identityHash = identityHash;
        record.lastUpdated = block.timestamp;

        emit ComplianceStatusUpdated(wallet, status, identityHash);
    }

    /**
     * @notice Checks if a wallet is currently approved for operations.
     */
    function isApproved(address wallet) external view returns (bool) {
        return identityRecords[wallet].status == ComplianceStatus.APPROVED;
    }

    /**
     * @notice Returns the identity hash for a given wallet.
     */
    function getIdentityHash(address wallet) external view returns (bytes32) {
        return identityRecords[wallet].identityHash;
    }

    /**
     * @notice Returns all wallets linked to a single identity hash.
     */
    function getWalletsByIdentity(bytes32 identityHash) external view returns (address[] memory) {
        return identityWallets[identityHash];
    }
}
