// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.12;
import "../libraries/BoringMath.sol";
import "../interfaces/IOracle.sol";

interface IUniswapAnchoredView {
    function price(string memory symbol) external view returns (uint256);
}

contract CompoundOracle is IOracle {
    using BoringMath for uint256;

    IUniswapAnchoredView constant private oracle = IUniswapAnchoredView(0x922018674c12a7F0D394ebEEf9B58F186CdE13c1);

    struct PairInfo {
        string collateralSymbol;
        string assetSymbol;
        uint256 division;
    }

    struct PriceInfo {
        uint128 price;
        uint128 blockNumber;
    }

    mapping(string => PriceInfo) prices;
    mapping(address => PairInfo) pairs; // Map of pairs and their info

    function _peekPrice(string memory symbol) internal view returns(uint256) {
        if (bytes(symbol).length == 0) {return 1000000;} // To allow only using collateralSymbol or assetSymbol if paired against USDx
        PriceInfo memory info = prices[symbol];
        if (block.number + 8 > info.blockNumber) {
            return uint128(oracle.price(symbol)); // Prices are denominated with 6 decimals, so will fit in uint128
        }
        return info.price;
    }

    function _getPrice(string memory symbol) internal returns(uint256) {
        if (bytes(symbol).length == 0) {return 1000000;} // To allow only using collateralSymbol or assetSymbol if paired against USDx
        PriceInfo memory info = prices[symbol];
        if (block.number + 8 > info.blockNumber) {
            info.price = uint128(oracle.price(symbol)); // Prices are denominated with 6 decimals, so will fit in uint128
            info.blockNumber = uint128(block.number); // Blocknumber will fit in uint128
            prices[symbol] = info;
        }
        return info.price;
    }

    // Adds a pair and it's data to the pair map
    function init(string calldata collateralSymbol, string calldata assetSymbol, uint256 division) public {
        // The rate can only be set once. It cannot be changed.
        if (bytes(pairs[msg.sender].collateralSymbol).length == 0) {
            pairs[msg.sender].collateralSymbol = collateralSymbol;
            pairs[msg.sender].assetSymbol = assetSymbol;
            pairs[msg.sender].division = division;
        }
    }

    // Calculates the lastest exchange rate
    function _get(string memory collateralSymbol, string memory assetSymbol, uint256 division) private returns (uint256) {
        return uint256(1e36)
            .mul(_getPrice(assetSymbol)) / _getPrice(collateralSymbol) / division;
    }

    // Calculates the lastest exchange rate
    function _peek(string memory collateralSymbol, string memory assetSymbol, uint256 division) private view returns (uint256) {
        return uint256(1e36)
            .mul(_peekPrice(assetSymbol)) / _peekPrice(collateralSymbol) / division;
    }

    // Get the latest exchange rate
    function get(address pair) public override returns (bool, uint256) {
        return (true, _get(pairs[pair].collateralSymbol, pairs[pair].assetSymbol, pairs[pair].division));
    }

    // Check the last exchange rate without any state changes
    function peek(address pair) public view override returns (uint256) {
        return _peek(pairs[pair].collateralSymbol, pairs[pair].assetSymbol, pairs[pair].division);
    }

    function test(string calldata collateralSymbol, string calldata assetSymbol, uint256 division) public view returns(uint256) {
        return _peek(collateralSymbol, assetSymbol, division);
    }
}
