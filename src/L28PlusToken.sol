// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title L28PlusToken
 * @notice Ecosystem Participation Incentive Token (Incentive-only).
 * @dev Structurally non-transferable and non-redeemable.
 */
contract L28PlusToken is ERC20, Ownable {
    event TokensGenerated(address indexed to, uint256 amount);

    constructor() ERC20("L28+ Incentive Token", "L28+") Ownable(msg.sender) {}

    /**
     * @notice Mints L28+ tokens for participation activity.
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit TokensGenerated(to, amount);
    }

    /**
     * @notice Structurally prevents all token transfers between participants.
     * @dev Only address(0) for minting and potentially burning is allowed.
     */
    function _update(address from, address to, uint256 value) internal override {
        require(from == address(0) || to == address(0), "L28+: Transfers not permitted");
        super._update(from, to, value);
    }

    /**
     * @notice Blocks allowance mechanisms to prevent indirect transfers.
     */
    function approve(address /* spender */, uint256 /* value */) public pure override returns (bool) {
        revert("L28+: Allowance not permitted");
    }

    function transferFrom(address /* from */, address /* to */, uint256 /* value */) public pure override returns (bool) {
        revert("L28+: Indirect transfers not permitted");
    }

    function allowance(address /* owner */, address /* spender */) public pure override returns (uint256) {
        return 0;
    }
}
