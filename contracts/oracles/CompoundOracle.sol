// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.12;
import "../libraries/BoringMath.sol";
import "../libraries/Ownable.sol";
import "../interfaces/IOracle.sol";

interface IUniswapAnchoredView {
    function price(string memory symbol) external view returns (uint256);
}

contract CompoundOracle is IOracle, Ownable {
    using BoringMath for uint256;

    struct PairInfo {
        string collateralSymbol;
        string supplySymbol;
        uint256 rate;
    }

    mapping(address => PairInfo) pairs; // Map of pairs and their info

    // Adds a pair and it's data to the pair map
    function init(string calldata collateralSymbol, string calldata supplySymbol, address pair) public {
        require(msg.sender == owner, "CompoundOracle: not owner");

        // The rate can only be set once. It cannot be changed.
        if (bytes(pairs[pair].collateralSymbol).length == 0) {
            pairs[pair].collateralSymbol = collateralSymbol;
            pairs[pair].supplySymbol = supplySymbol;
        }
    }

    // Encodes the initialization data
    function getInitData(string calldata collateralSymbol, string calldata supplySymbol) public pure returns (bytes memory) {
        return abi.encode(collateralSymbol, supplySymbol);
    }

    // Calculates the lastest exchange rate
    function _get(string memory collateralSymbol, string memory supplySymbol) private view returns (uint256) {
        return uint256(1e18)
            .mul(IUniswapAnchoredView(0xc629C26dcED4277419CDe234012F8160A0278a79).price(collateralSymbol))
            .div(IUniswapAnchoredView(0xc629C26dcED4277419CDe234012F8160A0278a79).price(supplySymbol));
    }

    // Get the latest exchange rate
    function get(address pair) public override returns (bool, uint256) {
        pairs[pair].rate = _get(pairs[pair].collateralSymbol, pairs[pair].supplySymbol);
        return (true, pairs[pair].rate);
    }

    // Check the last exchange rate without any state changes
    function peek(address pair) public view override returns (uint256) {
        return _get(pairs[pair].collateralSymbol, pairs[pair].supplySymbol);
    }

    function test(string calldata collateralSymbol, string calldata supplySymbol) public view returns(uint256) {
        return _get(collateralSymbol, supplySymbol);
    }
}