// Using the same Copyleft License as in the original Repository
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
import "../interfaces/IOracle.sol";
import "../interfaces/ILendingPair.sol";
import "../libraries/BoringMath.sol";

contract CompositeOracle is IOracle {
    using BoringMath for uint;

    struct PathInfo {
        address firstOracle;
        address firstPair;
        address secondOracle;
        address secondPair;
    }

    mapping(address => PathInfo) public paths; // Map of pairs and their path

    function init(
        address firstOracle,
        address firstPairAddress,
        address secondOracle,
        address secordPairAddress) public {
        ILendingPair firstPair = ILendingPair(firstPairAddress);
        ILendingPair secondPair = ILendingPair(secordPairAddress);
        require(address(firstPair.asset()) == address(secondPair.collateral()), "CompositeOracle: route does not connect");
        paths[msg.sender] = PathInfo(firstOracle, firstPairAddress, secondOracle, secordPairAddress);
    }

    function getInitData(
        address firstOracle,
        address firstPairAddress,
        address secondOracle,
        address secordPairAddress) public pure returns (bytes memory) {
        return abi.encodeWithSignature("init(address,address,address,address)", firstOracle, firstPairAddress, secondOracle, secordPairAddress);
    }

    // Get the latest exchange rate, if no valid (recent) rate is available, return false
    function get(address bentoPairAddress) external override returns (bool status, uint256 amountOut){
        PathInfo memory path = paths[bentoPairAddress];
        uint256 firstPrice;
        uint256 secondPrice;
        (,firstPrice) = IOracle(path.firstOracle).get(path.firstPair);
        (,secondPrice) = IOracle(path.secondOracle).get(path.secondPair);
        amountOut = firstPrice.mul(secondPrice) / 10**18;
    }

    // Check the last exchange rate without any state changes
    function peek(address bentoPairAddress) public view override returns (uint256 amountOut) {
        PathInfo memory path = paths[bentoPairAddress];
        amountOut = IOracle(path.firstOracle).peek(path.firstPair).mul(IOracle(path.secondOracle).peek(path.secondPair)) / 10**18;
    }

}
