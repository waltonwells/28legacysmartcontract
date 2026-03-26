// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ComplianceOracle.sol";
import "./EscrowOracle.sol";

/**
 * @title L28Token
 * @notice Identity-wrapped ERC-20 utility token for the 28LegacyGlobal ecosystem.
 * @dev Enforces escrow-gated minting and compliance-gated transfers.
 */
contract L28Token is ERC20, Ownable {
    ComplianceOracle public immutable complianceOracle;
    EscrowOracle public immutable escrowOracle;

    struct TokenMetadata {
        bytes32 escrowId;
        bytes32 identityHash;
        uint256 mintTimestamp;
    }

    // Mapping from address to metadata record for its tokens
    // Note: In an ERC-20, metadata is generally per-account, not per-token (like ERC-721).
    mapping(address => TokenMetadata) public identityMetadata;

    event TokensMinted(address indexed to, uint256 amount, bytes32 escrowId, bytes32 identityHash);
    event TokensBurned(address indexed from, uint256 amount, string reason);

    modifier onlyApproved(address wallet) {
        require(complianceOracle.isApproved(wallet), "Compliance check failed");
        _;
    }

    constructor(
        address _complianceOracle,
        address _escrowOracle
    ) ERC20("L28 Ecosystem Utility Token", "L28") Ownable(msg.sender) {
        complianceOracle = ComplianceOracle(_complianceOracle);
        escrowOracle = EscrowOracle(_escrowOracle);
    }

    /**
     * @notice Mints L28 tokens against a confirmed escrow record.
     * @param to The recipient of the tokens.
     * @param amount The amount to mint.
     * @param escrowId The unique escrow identifier.
     */
    function mint(
        address to,
        uint256 amount,
        bytes32 escrowId
    ) external onlyOwner onlyApproved(to) {
        require(escrowOracle.isConfirmed(escrowId), "Escrow not confirmed");
        require(escrowOracle.getEscrowAmount(escrowId) >= amount, "Insufficient escrow amount");

        // Identity-wrapping: link wallet to identity hash
        bytes32 identityHash = complianceOracle.getIdentityHash(to);
        require(identityHash != bytes32(0), "No identity linked");

        escrowOracle.consumeEscrow(escrowId);

        identityMetadata[to] = TokenMetadata({
            escrowId: escrowId,
            identityHash: identityHash,
            mintTimestamp: block.timestamp
        });

        _mint(to, amount);
        emit TokensMinted(to, amount, escrowId, identityHash);
    }

    /**
     * @notice Burns L28 tokens on redemption.
     */
    function burn(address from, uint256 amount, string calldata reason) external onlyOwner {
        _burn(from, amount);
        emit TokensBurned(from, amount, reason);
    }

    /**
     * @notice Overridden transfer to enforce compliance checks on both sender and receiver.
     */
    function _update(address from, address to, uint256 value) internal override {
        // Governance/Minting addresses (address(0)) bypass compliance checks if necessary,
        // but here we enforce it for all non-null transfers.
        if (from != address(0) && to != address(0)) {
            require(complianceOracle.isApproved(from), "Sender compliance check failed");
            require(complianceOracle.isApproved(to), "Receiver compliance check failed");
        }
        
        super._update(from, to, value);
    }

    /**
     * @notice Returns the identity metadata associated with a wallet.
     */
    function getMetadata(address wallet) external view returns (TokenMetadata memory) {
        return identityMetadata[wallet];
    }
}
