// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./BaseStrategy.sol";

/*  Example implementation stub to simplify strategy development.
	Please refer to the BaseStrategy contract natspec comments for
	further tips and clarifications. Also see the SushiStrategy and the
	AavePolygonStrategy for reference implementations. */
contract ExampleImplementation is BaseStrategy {
    // BaseStrategy initializes a immutable storage variable 'token' we can use

    constructor(address investmentContract, BaseStrategy.BaseStrategyParams memory baseStrategyParams) public BaseStrategy(baseStrategyParams) {
        baseStrategyParams.token.approve(investmentContract, type(uint256).max);
    }

    function _skim(uint256 amount) internal override {
        // assume token.balanceOf(address(this)) >= amount
        // invest the token
    }

    function _harvest(uint256 investedAmount) internal override returns (int256 delta) {
        // calculate the current amount we get if we withdraw the principal (not accounting for any received rewards)
        // if profitable, withdraw the surplus
        // return the difference between invested and current amount
    }

    function _harvestRewards() internal override {
        // implement the logic for claiming rewards and transfering them to address(this)
        // does not need to report the profits
        // skip if we expect no rewards
    }

    function _withdraw(uint256 amount) internal override {
        // withdraw the requested amount of tokens from the investment to address(this)
    }

    function _exit() internal override {
        // see what the available amount of tokens to withdraw is
        // withdraw as much tokens as possible from the investment to address(this)
        // should not revert
    }
}
