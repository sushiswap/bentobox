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

    IUniswapAnchoredView oracle;

    struct PairInfo {
        string collateralSymbol;
        string supplySymbol;
        uint256 rate;
    }

    mapping(address => PairInfo) pairs;

    constructor(IUniswapAnchoredView oracle_) public {
        oracle = oracle_;
    }

    function set(address pair, string calldata collateralSymbol, string calldata supplySymbol) public {
        require(msg.sender == owner, "CompoundOracle: not owner");

        // The rate can only be set once. It cannot be changed.
        if (bytes(pairs[pair].collateralSymbol).length == 0) {
            pairs[pair].collateralSymbol = collateralSymbol;
            pairs[pair].supplySymbol = supplySymbol;
        }
    }

    // Get the latest exchange rate
    function get(address pair) public override returns (bool, uint256) {
        pairs[pair].rate = uint256(1e18)
            .mul(oracle.price(pairs[pair].collateralSymbol))
            .div(oracle.price(pairs[pair].supplySymbol));
        return (true, pairs[pair].rate);
    }

    // Check the last exchange rate without any state changes
    function peek(address pair) public view override returns (uint256) {
        return uint256(1e18)
            .mul(oracle.price(pairs[pair].collateralSymbol))
            .div(oracle.price(pairs[pair].supplySymbol));
    }
}