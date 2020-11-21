// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "./IERC20.sol";

interface IFlashLoaner {
    function executeOperation(IERC20 token, uint256 amount, uint256 fee, bytes calldata params) external;
}