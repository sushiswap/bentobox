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
        address secondOracle;
    }

    mapping(address => PathInfo) public paths; // Map of pairs and their path

    function init(
        address firstOracle,
        bytes calldata firstOracleData,
        address secondOracle,
        bytes calldata secondOracleData) public {
        if (paths[msg.sender].firstOracle == address(0)) {
            bool success;
            (success,) = firstOracle.call(firstOracleData);
            require(success, 'CompositeOracle: oracle init failed.');
            (success,) = secondOracle.call(secondOracleData);
            require(success, 'CompositeOracle: oracle init failed.');
            paths[msg.sender] = PathInfo(firstOracle, secondOracle);        
        }
    }

    function getInitData(
        address firstOracle,
        bytes calldata firstOracleData,
        address secondOracle,
        bytes calldata secondOracleData) public pure returns (bytes memory) {
        return abi.encodeWithSignature("init(address,bytes,address,bytes)", firstOracle, firstOracleData, secondOracle, secondOracleData);
    }

    // Get the latest exchange rate, if no valid (recent) rate is available, return false
    function get(address bentoPairAddress) external override returns (bool status, uint256 amountOut){
        PathInfo memory path = paths[bentoPairAddress];
        uint256 firstPrice;
        uint256 secondPrice;
        (,firstPrice) = IOracle(path.firstOracle).get(address(this));
        (,secondPrice) = IOracle(path.secondOracle).get(address(this));
        amountOut = firstPrice.mul(secondPrice) / 10**18;
    }

    // Check the last exchange rate without any state changes
    function peek(address bentoPairAddress) public view override returns (uint256 amountOut) {
        PathInfo memory path = paths[bentoPairAddress];
        amountOut = IOracle(path.firstOracle).peek(address(this)).mul(IOracle(path.secondOracle).peek(address(this))) / 10**18;
    }

}
