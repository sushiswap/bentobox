// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IStrategy {
    function balance() external returns (uint256 amount);

    // Send the assets to the Strategy and call skim to invest them
    function skim() external returns (uint256 amount);

    // Harvest any profits made converted to the asset and pass them to the caller
    function harvest() external returns (int256 amountAdded);

    // Withdraw assets. The returned amount can differ from the requested amount due to rounding or if the request was more than there is.
    function withdraw(uint256 amount) external returns (int256 amountAdded);

    // Withdraw all assets in the safest way possible. This shouldn't fail.
    function exit() external returns (int256 amountAdded);
}