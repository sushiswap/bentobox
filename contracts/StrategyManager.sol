// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.12;
import "./interfaces/IStrategy.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";
// solhint-disable not-rely-on-time

struct StrategyData {
    uint64 strategyStartDate;
    uint64 targetPercentage;
    uint128 balance;
}

contract StrategyManager is BoringOwnable {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using BoringERC20 for IERC20;
    uint256 private constant STRATEGY_DELAY = 2 weeks;

    mapping(IERC20 => StrategyData) public strategyData;
    mapping(IERC20 => IStrategy) public strategy;
    mapping(IERC20 => IStrategy) public pendingStrategy;

    // F1 - F10: OK
    // C1 - C23: OK
    // C4: block.timestamp is used for a period of 2 weeks, which is long enough
    // F5: Not followed, but onwerOnly in BentoBox
    // Functions calling this must be onlyOwner
    function _setStrategy(IERC20 token, IStrategy newStrategy) internal returns (int256 amountAdded) {
        IStrategy pending = pendingStrategy[token];
        if (pending != newStrategy) {
            pendingStrategy[token] = newStrategy;
            strategyData[token].strategyStartDate = (block.timestamp + STRATEGY_DELAY).to64();
            amountAdded = 0;
        } else {
            StrategyData memory data = strategyData[token];
            require(data.strategyStartDate != 0 && block.timestamp >= data.strategyStartDate, "StrategyManager: Too early");
            amountAdded = address(strategy[token]) == address(0)
                ? 0
                : strategy[token].exit(data.balance); // REENT: Exit (under our control, safe)
            strategy[token] = pending;
            data.strategyStartDate = 0;
            data.balance = 0;
            strategyData[token] = data;
        }
    }

    // F1 - F10: OK
    // C1 - C23: OK
    // F5: Not followed to prevent reentrancy issues with flashloans and BentoBox skims?
    function _balanceStrategy(IERC20 token) internal {
        StrategyData memory data = strategyData[token];
        uint256 balance = token.balanceOf(address(this));
        uint256 targetBalance = balance.add(data.balance).mul(data.targetPercentage) / 100;
        if (data.balance < targetBalance) {
            IStrategy currentStrategy = strategy[token];
            uint256 amountOut = targetBalance.sub(data.balance);
            token.safeTransfer(address(currentStrategy), amountOut); // REENT: Exit (only for attack on other tokens)
            strategyData[token].balance = data.balance.add(amountOut.to128());
            currentStrategy.skim(data.balance); // REENT: Exit (under our control, safe)
        } else {
            uint256 amountIn = data.balance.sub(targetBalance.to128());
            strategyData[token].balance = data.balance.sub(amountIn.to128());
            strategy[token].withdraw(amountIn, data.balance); // REENT: Exit (only for attack on other tokens)
        }
    }

    uint256 private constant MAX_TARGET_PERCENTAGE = 95;

    // F1 - F10: OK
    // C1 - C23: OK
    function setStrategyTargetPercentage(IERC20 token, uint64 targetPercentage_) public onlyOwner {
        // Checks
        require(targetPercentage_ <= MAX_TARGET_PERCENTAGE, "StrategyManager: Target too high");

        // Effects
        strategyData[token].targetPercentage = targetPercentage_;
    }
}