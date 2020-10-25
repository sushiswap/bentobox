// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.12;
import "../libraries/BoringMath.sol";
import "../libraries/Ownable.sol";
import "../interfaces/IOracle.sol";

contract PeggedOracle is IOracle {
    using BoringMath for uint256;

    mapping(address => uint256) rate;

    function init(uint256 rate_) public {
        // The rate can only be set once. It cannot be changed.
        if (rate[msg.sender] == 0) {
            rate[msg.sender] = rate_;
        }
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