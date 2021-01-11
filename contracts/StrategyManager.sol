// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.12;
import "./interfaces/IStrategy.sol";
import "@bartjman/boring-solidity/contracts/BoringOwnable.sol";
import "@bartjman/boring-solidity/contracts/libraries/BoringMath.sol";
import "@bartjman/boring-solidity/contracts/libraries/BoringERC20.sol";
// solhint-disable not-rely-on-time

struct StrategyData {
    IStrategy strategy;
    IStrategy pendingStrategy;
    uint128 strategyStartDate;
    uint128 targetPercentage;
}

contract StrategyManager is BoringOwnable {
    using BoringMath for uint256;
    using BoringERC20 for IERC20;
    uint256 private constant STRATEGY_DELAY = 2 weeks;

    mapping(IERC20 => StrategyData) public strategy;

    function _setStrategy(IERC20 token, IStrategy newStrategy) internal returns (int256 amountAdded) {
        IStrategy pending = strategy[token].pendingStrategy;
        if (pending != newStrategy) {
            strategy[token].pendingStrategy = newStrategy;
            strategy[token].strategyStartDate = (block.timestamp + STRATEGY_DELAY).to128();
            amountAdded = 0;
        } else {
            uint128 strategyStartDate = strategy[token].strategyStartDate;
            require(strategyStartDate != 0 && block.timestamp >= strategyStartDate, "StrategyManager: Too early");
            amountAdded = strategy[token].strategy.exit();
            strategy[token].strategy = pending;
            strategy[token].strategyStartDate = 0;
        }
    }

    function _balanceStrategy(IERC20 token) internal returns (int256 amountAdded) {
        StrategyData memory data = strategy[token];
        uint256 committed = data.strategy.balance();
        uint256 balance = token.balanceOf(address(this));
        uint256 targetBalance = balance.add(committed).mul(data.targetPercentage) / 100;
        if (committed < targetBalance) {
            token.safeTransfer(address(data.strategy), targetBalance.sub(committed));
            data.strategy.skim();
            amountAdded = 0;
        } else {
            amountAdded = data.strategy.withdraw(committed.sub(targetBalance));
        }
    }

    function setStrategyTargetPercentage(IERC20 token, uint128 targetPercentage_) public onlyOwner {
        require(targetPercentage_ <= 95, "StrategyManager: Target too high");
        strategy[token].targetPercentage = targetPercentage_;
    }
}