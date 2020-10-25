// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.12;
import "../libraries/BoringMath.sol";
import "../libraries/Ownable.sol";
import "../interfaces/IOracle.sol";

// WARNING: This oracle is only for testing, please use PeggedOracle for a fixed value oracle
contract TestOracle is IOracle {
    using BoringMath for uint256;

    mapping(address => uint256) rate;

    function init(uint256 rate_) public {
        rate[msg.sender] = rate_;
    }

    function set(uint256 rate_, address pair) public {
        // The rate can be updated.
        rate[pair] = rate_;
    }

    function getInitData(uint256 rate_) public pure returns (bytes memory) {
        return abi.encodeWithSignature("init(uint256)", rate_);
    }

    // Get the latest exchange rate
    function get(address pair) public override returns (bool, uint256) {
        uint256 _rate = rate[pair];
        return (_rate != 0, _rate);
    }

    // Check the last exchange rate without any state changes
    function peek(address pair) public view override returns (uint256) {
        return rate[pair];
    }
}