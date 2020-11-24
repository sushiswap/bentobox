// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
// a library for performing overflow-safe math, updated with awesomeness from of DappHub (https://github.com/dapphub/ds-math)
library BoringMath {
    function add(uint a, uint b) internal pure returns (uint c) {require((c = a + b) >= b, "BoringMath: Add Overflow");}
    function sub(uint a, uint b) internal pure returns (uint c) {require((c = a - b) <= a, "BoringMath: Underflow");}
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    	// previous implementation:
    	// require(a == 0 || (c = a * b)/b == a
    	// was failing if b = 0
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "BoringMath: Mul Overflow");
        return c;
    }
}