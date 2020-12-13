pragma solidity 0.6.12;

// File: contracts\libraries\BoringMath.sol

// License-Identifier: MIT
// a library for performing overflow-safe math, updated with awesomeness from of DappHub (https://github.com/dapphub/ds-math)
library BoringMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {require((c = a + b) >= b, "BoringMath: Add Overflow");}
    function sub(uint256 a, uint256 b) internal pure returns (uint256 c) {require((c = a - b) <= a, "BoringMath: Underflow");}
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {require(b == 0 || (c = a * b)/b == a, "BoringMath: Mul Overflow");}
    function to128(uint256 a) internal pure returns (uint128 c) {
        require(a <= uint128(-1), "BoringMath: uint128 Overflow");
        c = uint128(a);
    }
}

library BoringMath128 {
    function add(uint128 a, uint128 b) internal pure returns (uint128 c) {require((c = a + b) >= b, "BoringMath: Add Overflow");}
    function sub(uint128 a, uint128 b) internal pure returns (uint128 c) {require((c = a - b) <= a, "BoringMath: Underflow");}
}

// File: contracts\interfaces\IOracle.sol

// License-Identifier: MIT

interface IOracle {
    // Get the latest exchange rate, if no valid (recent) rate is available, return false
    function get(bytes calldata data) external returns (bool, uint256);
    function peek(bytes calldata data) external view returns (bool, uint256);
    function symbol(bytes calldata data) external view returns (string memory);
    function name(bytes calldata data) external view returns (string memory);
}

// File: contracts\oracles\TestOracle.sol

// SPDX-License-Identifier: MIT



// WARNING: This oracle is only for testing, please use PeggedOracle for a fixed value oracle
contract TestOracle is IOracle {
    using BoringMath for uint256;

    uint256 rate;

    function set(uint256 rate_, address) public {
        // The rate can be updated.
        rate = rate_;
    }

    function getDataParameter() public pure returns (bytes memory) { return abi.encode("0x0"); }

    // Get the latest exchange rate
    function get(bytes calldata) public override returns (bool, uint256) {
        return (true, rate);
    }

    // Check the last exchange rate without any state changes
    function peek(bytes calldata) public override view returns (bool, uint256) {
        return (true, rate);
    }

    function name(bytes calldata) public override view returns (string memory) {
        return "Test";
    }

    function symbol(bytes calldata) public override view returns (string memory) {
        return "TEST";
    }
}
