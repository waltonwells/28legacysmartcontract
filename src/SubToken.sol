// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ComplianceOracle.sol";
import "./EscrowOracle.sol";

/**
 * @title SubToken
 * @notice Project-specific participation token.
 * @dev Enforces 20% concentration limit per identity.
 *      Uses burn-and-remint logic for identity tracking.
 */
contract SubToken is ERC20, Ownable {
    ComplianceOracle public immutable complianceOracle;
    EscrowOracle public immutable escrowOracle;

    bytes32 public immutable projectId;
    uint256 public immutable maxSupply;
    uint256 public immutable concentrationLimit; // Basis points: 2000 = 20%

    // Total balance per identityHash across all linked wallets
    mapping(bytes32 => uint256) public identityBalances;

    // Track identity metadata for each wallet
    mapping(address => bytes32) public walletIdentities;

    event ParticipationIssued(address indexed participant, uint256 amount, bytes32 identityHash);
    event ParticipationReminted(address indexed from, address indexed to, uint256 amount, bytes32 identityHash);

    modifier onlyApproved(address wallet) {
        require(complianceOracle.isApproved(wallet), "Compliance check failed");
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        bytes32 _projectId,
        uint256 _maxSupply,
        address _complianceOracle,
        address _escrowOracle
    ) ERC20(name, symbol) Ownable(msg.sender) {
        projectId = _projectId;
        maxSupply = _maxSupply;
        complianceOracle = ComplianceOracle(_complianceOracle);
        escrowOracle = EscrowOracle(_escrowOracle);
        concentrationLimit = 2000; // 20%
    }

    /**
     * @notice Mints participation tokens against a confirmed escrow.
     */
    function mint(address to, uint256 amount, bytes32 escrowId) external onlyOwner onlyApproved(to) {
        require(totalSupply() + amount <= maxSupply, "Max supply exceeded");
        require(escrowOracle.isConfirmed(escrowId), "Escrow not confirmed");
        
        bytes32 identityHash = complianceOracle.getIdentityHash(to);
        require(identityHash != bytes32(0), "No identity linked");

        _checkConcentrationLimit(identityHash, amount);

        escrowOracle.consumeEscrow(escrowId);
        
        identityBalances[identityHash] += amount;
        walletIdentities[to] = identityHash;

        _mint(to, amount);
        emit ParticipationIssued(to, amount, identityHash);
    }

    /**
     * @notice Overrides transfer to use burn-and-remint logic for compliance/identity attribution.
     * @dev Ensures tokens always reflect the current verified holder's identity.
     */
    function transfer(address to, uint256 amount) public override onlyApproved(msg.sender) onlyApproved(to) returns (bool) {
        bytes32 fromIdentity = walletIdentities[msg.sender];
        bytes32 toIdentity = complianceOracle.getIdentityHash(to);
        
        require(fromIdentity != bytes32(0), "Sender identity missing");
        require(toIdentity != bytes32(0), "Receiver identity missing");

        _checkConcentrationLimit(toIdentity, amount);

        // Update identity balances
        identityBalances[fromIdentity] -= amount;
        identityBalances[toIdentity] += amount;
        walletIdentities[to] = toIdentity;

        // Burn and remint (logic handled via standard transfer plus identity update)
        super.transfer(to, amount);
        
        emit ParticipationReminted(msg.sender, to, amount, toIdentity);
        return true;
    }

    function _checkConcentrationLimit(bytes32 identityHash, uint256 additionalAmount) internal view {
        uint256 totalIdentityBalance = identityBalances[identityHash] + additionalAmount;
        // 20% limit of max supply
        uint256 limitAmount = (maxSupply * concentrationLimit) / 10000;
        require(totalIdentityBalance <= limitAmount, "Concentration limit exceeded (20%)");
    }

    /**
     * @notice Returns total holdings of a specific identity across all wallets.
     */
    function getIdentityBalance(bytes32 identityHash) external view returns (uint256) {
        return identityBalances[identityHash];
    }
}
