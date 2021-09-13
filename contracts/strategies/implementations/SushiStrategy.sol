// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../BaseStrategy.sol";

interface ISushiBar is IERC20 {
    function enter(uint256 _amount) external;

    function leave(uint256 _share) external;
}

contract SushiStrategy is BaseStrategy {
    ISushiBar public immutable sushiBar;

    constructor(ISushiBar _sushiBar, BaseStrategyParams memory baseStrategyParams) public BaseStrategy(baseStrategyParams) {
        sushiBar = _sushiBar;
        IERC20(baseStrategyParams.token).approve(address(_sushiBar), type(uint256).max);
    }

    function _skim(uint256 amount) internal override {
        sushiBar.enter(amount);
    }

    function _harvest(uint256 balance) internal override returns (int256) {
        uint256 keep = toShare(balance);
        uint256 total = sushiBar.balanceOf(address(this));
        if (total > keep) sushiBar.leave(total - keep);
        // xSUSHI can't report a loss so no need to check for keep < total case
        return int256(0);
    }

    function _withdraw(uint256 amount) internal override {
        uint256 requested = toShare(amount);
        uint256 actual = sushiBar.balanceOf(address(this));
        sushiBar.leave(requested > actual ? actual : requested);
    }

    function _exit() internal override {
        sushiBar.leave(sushiBar.balanceOf(address(this)));
    }

    function toShare(uint256 amount) internal view returns (uint256) {
        uint256 totalShares = sushiBar.totalSupply();
        uint256 totalSushi = strategyToken.safeBalanceOf(address(sushiBar));
        return amount.mul(totalShares) / totalSushi;
    }
}
