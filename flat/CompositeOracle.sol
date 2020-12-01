pragma solidity 0.6.12;

// File: contracts\libraries\BoringMath.sol
// License-Identifier: MIT
// a library for performing overflow-safe math, updated with awesomeness from of DappHub (https://github.com/dapphub/ds-math)
library BoringMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {require((c = a + b) >= b, "BoringMath: Add Overflow");}
    function sub(uint256 a, uint256 b) internal pure returns (uint256 c) {require((c = a - b) <= a, "BoringMath: Underflow");}
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {require(b == 0 || (c = a * b)/b == a, "BoringMath: Mul Overflow");}
}

// File: contracts\interfaces\IOracle.sol
// License-Identifier: MIT
interface IOracle {
    // Get the latest exchange rate, if no valid (recent) rate is available, return false
    function get(bytes calldata data) external returns (bool, uint256);
    function peek(bytes calldata data) external view returns (bool, uint256);
}

// File: contracts\oracles\CompositeOracle.sol
// Using the same Copyleft License as in the original Repository
// SPDX-License-Identifier: AGPL-3.0-only
contract CompositeOracle is IOracle {
    using BoringMath for uint256;

    function getDataParameter(IOracle oracle1, IOracle oracle2, bytes memory data1, bytes memory data2) public pure returns (bytes memory)
    {
        return abi.encode(oracle1, oracle2, data1, data2);
    }

    // Get the latest exchange rate, if no valid (recent) rate is available, return false
    function get(bytes calldata data) external override returns (bool status, uint256 amountOut){
        (IOracle oracle1, IOracle oracle2, bytes memory data1, bytes memory data2) = abi.decode(data, (IOracle, IOracle, bytes, bytes));
        (bool success1, uint256 price1) = oracle1.get(data1);
        (bool success2, uint256 price2) = oracle2.get(data2);
        return (success1 && success2, price1.mul(price2) / 10**18);
    }

    // Check the last exchange rate without any state changes
    function peek(bytes calldata data) public override view returns (bool success, uint256 amountOut) {
        (IOracle oracle1, IOracle oracle2, bytes memory data1, bytes memory data2) = abi.decode(data, (IOracle, IOracle, bytes, bytes));
        (bool success1, uint256 price1) = oracle1.peek(data1);
        (bool success2, uint256 price2) = oracle2.peek(data2);
        return (success1 && success2, price1.mul(price2) / 10**18);
    }
}
