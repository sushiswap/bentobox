// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "../interfaces/IOracle.sol";

// Chainlink Aggregator
interface IAggregator {
    function latestRoundData()
        external
        view
        returns (
            uint80,
            int256 answer,
            uint256,
            uint256,
            uint80
        );
}

contract ChainlinkOracle is IOracle {
    using BoringMath for uint256; // Keep everything in uint256

    // Calculates the lastest exchange rate
    // Uses both divide and multiply only for tokens not supported directly by Chainlink, for example MKR/USD
    function _get(
        address multiply,
        address divide,
        uint256 decimals
    ) public view returns (uint256) {
        uint256 price = uint256(1e18);
        if (multiply != address(0)) {
            // We only care about the second value - the price
            (, int256 priceC, , , ) = IAggregator(multiply).latestRoundData();
            price = price.mul(uint256(priceC));
        } else {
            price = price.mul(1e18);
        }

        if (divide != address(0)) {
            // We only care about the second value - the price
            (, int256 priceC, , , ) = IAggregator(divide).latestRoundData();
            price = price / uint256(priceC);
        }

        return price / decimals;
    }

    function getDataParameter(
        address multiply,
        address divide,
        uint256 decimals
    ) public pure returns (bytes memory) {
        return abi.encode(multiply, divide, decimals);
    }

    // Get the latest exchange rate
    /// @inheritdoc IOracle
    function get(bytes calldata data) public override returns (bool, uint256) {
        (address multiply, address divide, uint256 decimals) = abi.decode(data, (address, address, uint256));
        return (true, _get(multiply, divide, decimals));
    }

    // Check the last exchange rate without any state changes
    /// @inheritdoc IOracle
    function peek(bytes calldata data) public view override returns (bool, uint256) {
        (address multiply, address divide, uint256 decimals) = abi.decode(data, (address, address, uint256));
        return (true, _get(multiply, divide, decimals));
    }

    /// @inheritdoc IOracle
    function name(bytes calldata) public view override returns (string memory) {
        return "Chainlink";
    }

    /// @inheritdoc IOracle
    function symbol(bytes calldata) public view override returns (string memory) {
        return "LINK";
    }
}
