// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.12;
import "../libraries/BoringMath.sol";
import "../libraries/Ownable.sol";
import "../interfaces/IOracle.sol";

contract SLPOracle is IOracle, Ownable {
    struct PairInfo {
        string collateralSymbol;
        string supplySymbol;
        uint256 rate;
    }

    mapping(address => PairInfo) pairs;

    function init(uint256 rate_, address pair) public {
        require(msg.sender == owner, "SLPOracle: not owner");
    }

    function getInitData(uint256 rate_) public pure returns (bytes memory) {
        return abi.encode(rate_);
    }

    // Get the latest exchange rate
    function get(address pair) public override returns (bool, uint256) {
        return (true, 0);
    }

    // Check the last exchange rate without any state changes
    function peek(address pair) public view override returns (uint256) {
        return 0;
    }
}
