// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./IERC20.sol";

interface IFlashLoaner {
    function executeOperation(IERC20 token, uint256 amount, uint256 fee, bytes calldata params) external;
    function executeOperationMultiple(
        IERC20[] calldata tokens, uint256[] calldata amounts, uint256[] calldata fees, bytes calldata params) external;
}
