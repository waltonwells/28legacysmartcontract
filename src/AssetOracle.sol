// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AssetOracle
 * @notice Provides real-time asset valuation using Chainlink Price Feeds.
 * @dev Used for NAV (Net Asset Value) calculations for SubTokens.
 */
contract AssetOracle is Ownable {
    struct AssetValuation {
        address priceFeed; // Chainlink Aggregator address
        uint256 totalAssetUnits; // e.g., square feet, ounces of gold
        uint256 liabilities; // Fixed liabilities in AED/USD
        uint8 decimals; // Decimals of the price feed
    }

    // Mapping from projectId to its valuation configuration
    mapping(bytes32 => AssetValuation) public assetValuations;

    event AssetPriceFeedUpdated(bytes32 indexed projectId, address priceFeed);
    event AssetValuationUpdated(bytes32 indexed projectId, uint256 totalUnits, uint256 liabilities);

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Configures or updates the Chainlink price feed and units for a project.
     * @param projectId Unique project identifier.
     * @param priceFeed Address of the Chainlink AggregatorV3Interface.
     * @param totalUnits Total quantity of the underlying asset.
     * @param liabilities Total project liabilities in base currency.
     */
    function updateAssetConfig(
        bytes32 projectId,
        address priceFeed,
        uint256 totalUnits,
        uint256 liabilities
    ) external onlyOwner {
        require(priceFeed != address(0), "Invalid price feed address");
        
        AggregatorV3Interface feed = AggregatorV3Interface(priceFeed);
        
        assetValuations[projectId] = AssetValuation({
            priceFeed: priceFeed,
            totalAssetUnits: totalUnits,
            liabilities: liabilities,
            decimals: feed.decimals()
        });

        emit AssetPriceFeedUpdated(projectId, priceFeed);
    }

    /**
     * @notice Fetches the latest price from Chainlink.
     */
    function getLatestPrice(bytes32 projectId) public view returns (int) {
        AssetValuation storage valuation = assetValuations[projectId];
        require(valuation.priceFeed != address(0), "Price feed not configured");

        AggregatorV3Interface feed = AggregatorV3Interface(valuation.priceFeed);
        (
            /* uint80 roundID */,
            int price,
            /* uint startedAt */,
            /* uint timeStamp */,
            /* uint80 answeredInRound */
        ) = feed.latestRoundData();
        
        return price;
    }

    /**
     * @notice Calculates the Net Asset Value (NAV) for a project.
     * @dev NAV = (Total Asset Units * Current Price - Liabilities) / Total Token Supply.
     * @param projectId Project identifier.
     * @param totalTokenSupply Current supply of SubTokens for this project.
     * @return nav The calculated NAV in base currency.
     */
    function calculateNAV(bytes32 projectId, uint256 totalTokenSupply) external view returns (uint256) {
        AssetValuation storage valuation = assetValuations[projectId];
        require(valuation.priceFeed != address(0), "Price feed not configured");
        require(totalTokenSupply > 0, "Token supply must be greater than zero");

        int currentPrice = getLatestPrice(projectId);
        require(currentPrice > 0, "Price must be positive");

        uint256 totalAssetValue = (valuation.totalAssetUnits * uint256(currentPrice));
        
        // Ensure asset value covers liabilities
        if (totalAssetValue <= valuation.liabilities) {
            return 0;
        }

        // Scale by 1e18 to maintain precision during division
        uint256 nav = ((totalAssetValue - valuation.liabilities) * 1e18) / totalTokenSupply;
        return nav;
    }
}
