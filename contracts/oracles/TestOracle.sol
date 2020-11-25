// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "../libraries/BoringMath.sol";
import "../libraries/Ownable.sol";
import "../interfaces/IOracle.sol";

// WARNING: This oracle is only for testing, please use PeggedOracle for a fixed value oracle
contract TestOracle is IOracle {
    using BoringMath for uint256;

    uint256 rate;

    function init() external {
    }

    function set(uint256 rate_, address) public {
        // The rate can be updated.
        rate = rate_;
    }

    function getDataParameter() public pure returns (bytes memory) { return abi.encode(); }

    // Get the latest exchange rate
    function get(bytes calldata) public override returns (bool, uint256) {
        if (rate == 0) {
            return (false, rate);
        }
        return (true, rate);
    }

    // Check the last exchange rate without any state changes
    function peek(bytes calldata) public override view returns (bool, uint256) {
        return (true, rate);
    }
}
