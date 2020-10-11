// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.12;
import "../libraries/BoringMath.sol";
import "../libraries/Ownable.sol";
import "../interfaces/IOracle.sol";

contract PeggedOracle is IOracle, Ownable {
    using BoringMath for uint256;

    mapping(address => uint256) rate;

    function set(address pair, uint256 rate_) public {
        require(msg.sender == owner, "PeggedOracle: not owner");

        // The rate can only be set once. It cannot be changed.
        if (rate[pair] == 0) {
            rate[pair] = rate_;
        }
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