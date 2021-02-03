// SPDX-License-Identifier: MIT
// solium-disable security/no-tx-origin

// TokenA does not revert on errors, it just returns false
pragma solidity 0.6.12;
import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";


contract ExternalFunctionMock {
    using BoringMath for uint256;

    event Result(uint256 output);
    
    function sum(uint256 a, uint256 b) external returns (uint256 c) {
        c = a.add(b);
        emit Result(c);
    }
}