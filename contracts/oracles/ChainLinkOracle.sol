// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.12;
import "../libraries/BoringMath.sol";
import "../libraries/Ownable.sol";
import "./IOracle.sol";

// ChainLink Aggregator
interface IAggregator {
    function latestRoundData() external view returns (uint80, int256 answer, uint256, uint256, uint80);
}

contract ChainlinkOracle is Ownable, IOracle {
    using BoringMath for uint256; // Keep everything in uint256

    struct SymbolPair {
        address multiply;   // The ChainLink price to multiply by to get rate
        address divide;     // The ChainLink price to divide by to get rate
        uint256 decimals;   // Just pre-calc and store as something like 10000000000000000000000.
        uint256 rate;
    }

    mapping(address => SymbolPair) symbols;

    function set(address pair, address multiply, address divide, uint256 decimals) public {
        require(msg.sender == owner, "ChainlinkOracle: not owner");

        // The rate can only be set once. It cannot be changed.
        if (symbols[pair].decimals == 0) {
            symbols[pair].multiply = multiply;
            symbols[pair].divide = divide;
            symbols[pair].decimals = decimals;
        }
    }

    // Get the latest exchange rate
    function get(address pair) public override returns (bool, uint256) {
        uint256 price = uint256(1e18);
        SymbolPair storage s = symbols[pair];
        address multiply = s.multiply;
        address divide = s.divide;

        if (multiply != address(0)) {
            (, int256 priceC,,,) = IAggregator(multiply).latestRoundData();
            price = price.mul(uint256(priceC));
        } else {
            price = price.mul(1e18);
        }

        if (divide != address(0)) {
            (, int256 priceC,,,) = IAggregator(divide).latestRoundData();
            price = price.div(uint256(priceC));
        }

        if (multiply != address(0)) {
            price = price.div(1e18);
        }

        price = price.div(s.decimals);
        s.rate = price;
        return (true, price);
    }

    // Check the last exchange rate without any state changes
    function peek(address pair) public override view returns (uint256) {
        uint256 price = uint256(1e18);
        SymbolPair storage s = symbols[pair];
        address multiply = s.multiply;
        address divide = s.divide;

        if (multiply != address(0)) {
            (, int256 priceC,,,) = IAggregator(multiply).latestRoundData();
            price = price.mul(uint256(priceC));
        } else {
            price = price.mul(1e18);
        }

        if (divide != address(0)) {
            (, int256 priceC,,,) = IAggregator(divide).latestRoundData();
            price = price.div(uint256(priceC));
        }

        if (multiply != address(0)) {
            price = price.div(1e18);
        }

        price = price.div(s.decimals);
        return price;
    }
}