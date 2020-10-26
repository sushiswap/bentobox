// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.12;
import "../libraries/BoringMath.sol";
import "../libraries/Ownable.sol";
import "../interfaces/IOracle.sol";

interface IUniswapAnchoredView {
    function price(string memory symbol) external view returns (uint256);
}

contract CompoundOracle is IOracle {
    using BoringMath for uint256;

    struct PairInfo {
        string collateralSymbol;
        string assetSymbol;
        uint256 division;
    }

    mapping(address => PairInfo) pairs; // Map of pairs and their info

    // Adds a pair and it's data to the pair map
    function init(string calldata collateralSymbol, string calldata assetSymbol, uint256 division) public {
        // The rate can only be set once. It cannot be changed.
        if (bytes(pairs[msg.sender].collateralSymbol).length == 0) {
            pairs[msg.sender].collateralSymbol = collateralSymbol;
            pairs[msg.sender].assetSymbol = assetSymbol;
            pairs[msg.sender].division = division;
        }
    }

    // Encodes the initialization data
    function getInitData(string calldata collateralSymbol, string calldata assetSymbol, uint256 division) public pure returns (bytes memory) {
        return abi.encodeWithSignature("init(string,string,uint256)", collateralSymbol, assetSymbol, division);
    }

    // Calculates the lastest exchange rate
    function _get(string memory collateralSymbol, string memory assetSymbol, uint256 division) private view returns (uint256) {
        return uint256(1e36)
            .mul(IUniswapAnchoredView(0x922018674c12a7F0D394ebEEf9B58F186CdE13c1).price(assetSymbol)) /
                IUniswapAnchoredView(0x922018674c12a7F0D394ebEEf9B58F186CdE13c1).price(collateralSymbol) / division;
    }

    // Get the latest exchange rate
    function get(address pair) public override returns (bool, uint256) {
        return (true, _get(pairs[pair].collateralSymbol, pairs[pair].assetSymbol, pairs[pair].division));
    }

    // Check the last exchange rate without any state changes
    function peek(address pair) public view override returns (uint256) {
        return _get(pairs[pair].collateralSymbol, pairs[pair].assetSymbol, pairs[pair].division);
    }

    function test(string calldata collateralSymbol, string calldata assetSymbol, uint256 division) public view returns(uint256) {
        return _get(collateralSymbol, assetSymbol, division);
    }
}