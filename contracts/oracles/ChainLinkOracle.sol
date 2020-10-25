// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.12;
import "../libraries/BoringMath.sol";
import "../libraries/Ownable.sol";
import "../interfaces/IOracle.sol";

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

    mapping(address => SymbolPair) symbols; // Map of pairs and their info

    // Adds a pair and it's data to the pair map
    function init(address multiply, address divide, uint256 decimals, address pair) public {
        require(msg.sender == owner, "ChainlinkOracle: not owner");

        // The rate can only be set once. It cannot be changed.
        if (symbols[pair].decimals == 0) {
            symbols[pair].multiply = multiply;
            symbols[pair].divide = divide;
            symbols[pair].decimals = decimals;
        }
    }

    // Encodes the initialization data
    function getInitData(address multiply, address divide, uint256 decimals) public pure returns (bytes memory) {
        return abi.encode(multiply, divide, decimals);
    }

    // Calculates the lastest exchange rate
    // Uses both divide and multiply only for tokens not supported directly by ChainLink, for example MKR/USD
    function _get(address multiply, address divide, uint256 decimals) public view returns (uint256) {
        uint256 price = uint256(1e18);
        if (multiply != address(0)) {
            // We only care about the second value - the price
            (, int256 priceC,,,) = IAggregator(multiply).latestRoundData();
            price = price.mul(uint256(priceC));
        } else {
            price = price.mul(1e18);
        }

        if (divide != address(0)) {
            // We only care about the second value - the price
            (, int256 priceC,,,) = IAggregator(divide).latestRoundData();
            price = price.div(uint256(priceC));
        }

        return price.div(decimals);
    }

    // Get the latest exchange rate
    function get(address pair) public override returns (bool, uint256) {
        SymbolPair storage s = symbols[pair];
        uint256 rate = _get(s.multiply, s.divide, s.decimals);
        s.rate = rate;
        return (true, rate);
    }

    // Check the last exchange rate without any state changes
    function peek(address pair) public override view returns (uint256) {
        SymbolPair storage s = symbols[pair];
        return _get(s.multiply, s.divide, s.decimals);
    }

    function test(address multiply, address divide, uint256 decimals) public view returns(uint256) {
        return _get(multiply, divide, decimals);
    }
}