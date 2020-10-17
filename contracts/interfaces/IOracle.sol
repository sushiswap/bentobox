// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IOracle {
    // Each oracle should have a set function. The first parameter will be 'address pair' and any parameters can come after.
    // Setting should only be allowed ONCE for each pair.

    // Get the latest exchange rate, if no valid (recent) rate is available, return false
    function get(address pair) external returns (bool, uint256);

    // Check the last exchange rate without any state changes
    function peek(address pair) external view returns (uint256);
}