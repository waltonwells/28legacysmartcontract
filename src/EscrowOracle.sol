// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EscrowOracle
 * @notice On-chain registry for confirming deposit escrow records.
 * @dev Managed by the Treasury and Escrow service layer.
 */
contract EscrowOracle is Ownable {
    struct EscrowRecord {
        uint256 amount;
        bool confirmed;
        bool consumed; // Mark as consumed once used for minting
        uint256 timestamp;
        bytes32 depositRef; // Unique reference to the originating transaction
    }

    // Mapping from unique escrowId to record
    mapping(bytes32 => EscrowRecord) public escrowRecords;

    // Authorized service wallets (Treasury Service)
    mapping(address => bool) public authorizedCallers;

    event EscrowConfirmed(bytes32 indexed escrowId, uint256 amount, bytes32 depositRef);
    event EscrowConsumed(bytes32 indexed escrowId);
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
     * @notice Confirms a deposit escrow in the registry.
     * @param escrowId Unique identifier generated for the deposit.
     * @param amount The amount deposited in fiat equivalent (AED/USD).
     * @param depositRef Reference to the bank wire or crypto transaction.
     */
    function confirmEscrow(
        bytes32 escrowId,
        uint256 amount,
        bytes32 depositRef
    ) external onlyAuthorized {
        require(escrowRecords[escrowId].amount == 0, "Escrow already exists");
        
        escrowRecords[escrowId] = EscrowRecord({
            amount: amount,
            confirmed: true,
            consumed: false,
            timestamp: block.timestamp,
            depositRef: depositRef
        });

        emit EscrowConfirmed(escrowId, amount, depositRef);
    }

    /**
     * @notice Checks if an escrow record is confirmed and not yet consumed.
     */
    function isConfirmed(bytes32 escrowId) external view returns (bool) {
        EscrowRecord storage record = escrowRecords[escrowId];
        return record.confirmed && !record.consumed;
    }

    /**
     * @notice Marks an escrow record as consumed.
     * @dev Called by the Tokenization Engine during minting.
     */
    function consumeEscrow(bytes32 escrowId) external onlyAuthorized {
        require(escrowRecords[escrowId].confirmed, "Escrow not confirmed");
        require(!escrowRecords[escrowId].consumed, "Escrow already consumed");

        escrowRecords[escrowId].consumed = true;
        emit EscrowConsumed(escrowId);
    }

    /**
     * @notice Returns the amount of an escrow record.
     */
    function getEscrowAmount(bytes32 escrowId) external view returns (uint256) {
        return escrowRecords[escrowId].amount;
    }
}
