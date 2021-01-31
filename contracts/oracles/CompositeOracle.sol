// SPDX-License-Identifier: AGPL-3.0-only

// Using the same Copyleft License as in the original Repository
pragma solidity 0.6.12;
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "../interfaces/IOracle.sol";

contract CompositeOracle is IOracle {
    using BoringMath for uint256;

    function getDataParameter(IOracle oracle1, IOracle oracle2, bytes memory data1, bytes memory data2) public pure returns (bytes memory) {
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

    function name(bytes calldata data) public override view returns (string memory) {
        (IOracle oracle1, IOracle oracle2, bytes memory data1, bytes memory data2) = abi.decode(data, (IOracle, IOracle, bytes, bytes));
        return string(abi.encodePacked(oracle1.name(data1), "+", oracle2.name(data2)));
    }

    function symbol(bytes calldata data) public override view returns (string memory) {
        (IOracle oracle1, IOracle oracle2, bytes memory data1, bytes memory data2) = abi.decode(data, (IOracle, IOracle, bytes, bytes));
        return string(abi.encodePacked(oracle1.symbol(data1), "+", oracle2.symbol(data2)));
    }
}
