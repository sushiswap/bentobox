// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IVault {
    function swappers(address swapper) external returns (bool);
    function transfer(address token, address to, uint256 amount) external;
    function transferFrom(address token, address from, uint256 amount) external;
}