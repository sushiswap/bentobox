// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./BaseStrategy.sol";

library DataTypes {
    struct ReserveData {
        ReserveConfigurationMap configuration;
        uint128 liquidityIndex;
        uint128 variableBorrowIndex;
        uint128 currentLiquidityRate;
        uint128 currentVariableBorrowRate;
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        address interestRateStrategyAddress;
        uint8 id;
    }

    struct ReserveConfigurationMap {
        uint256 data;
    }
}

interface ILendingPool {
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);
}

contract AaveStrategyNew is BaseStrategy {
    ILendingPool public immutable aaveLendingPool;
    IERC20 public immutable aToken;

    constructor(
        ILendingPool _aaveLendingPool,
        IERC20 _underlying,
        IBentoBoxMinimal _bentoBox,
        address _strategyExecutor,
        address _factory,
        address[][] memory paths
    ) public BaseStrategy(_underlying, _bentoBox, _strategyExecutor, _factory, paths) {
        aaveLendingPool = _aaveLendingPool;
        aToken = IERC20(_aaveLendingPool.getReserveData(address(_underlying)).aTokenAddress);
        _underlying.approve(address(_aaveLendingPool), type(uint256).max);
    }

    function _skim(uint256 amount) internal override {
        aaveLendingPool.deposit(address(underlying), amount, address(this), 0);
    }

    function _harvest(uint256 balance) internal override returns (int256 amountAdded) {
        uint256 currentBalance = IERC20(aToken).safeBalanceOf(address(this));
        amountAdded = int256(currentBalance) - int256(balance);
        if (amountAdded > 0) aaveLendingPool.withdraw(address(underlying), currentBalance - balance, address(this));
        /// @dev compiler error when using uint256(amountAdded) instead of currentBalance - balance ¯\_(ツ)_/¯
    }

    function _withdraw(uint256 amount) internal override {
        aaveLendingPool.withdraw(address(underlying), amount, address(this));
    }

    function _exit() internal override {
        uint256 tokenBalance = aToken.safeBalanceOf(address(this));
        uint256 available = underlying.safeBalanceOf(address(aToken));
        if (tokenBalance <= available) {
            /// @dev If there are more tokens available than our full position, take all based on aToken balance (continue if unsuccessful).
            try aaveLendingPool.withdraw(address(underlying), tokenBalance, address(this)) {} catch {}
        } else {
            /// @dev Otherwise redeem all available and take a loss on the missing amount (continue if unsuccessful).
            try aaveLendingPool.withdraw(address(underlying), available, address(this)) {} catch {}
        }
    }

    function _harvestRewards() internal override {
        // TODO
    }
}
