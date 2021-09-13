// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../BaseStrategy.sol";

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

interface IAaveIncentivesController {
    function getRewardsBalance(address[] calldata assets, address user) external view returns (uint256);

    function claimRewards(
        address[] calldata assets,
        uint256 amount,
        address to
    ) external returns (uint256);
}

contract AaveStrategy is BaseStrategy {
    IERC20 public immutable rewardToken;
    ILendingPool public immutable aaveLendingPool;
    IAaveIncentivesController public immutable incentiveController;
    IERC20 public immutable aToken;

    constructor(
        IERC20 _rewardToken,
        ILendingPool _aaveLendingPool,
        IAaveIncentivesController _incentiveController,
        BaseStrategyParams memory baseStrategyParams
    ) public BaseStrategy(baseStrategyParams) {
        rewardToken = _rewardToken;
        aaveLendingPool = _aaveLendingPool;
        incentiveController = _incentiveController;
        aToken = IERC20(_aaveLendingPool.getReserveData(address(baseStrategyParams.token)).aTokenAddress);
        baseStrategyParams.token.approve(address(_aaveLendingPool), type(uint256).max);
    }

    function _skim(uint256 amount) internal override {
        aaveLendingPool.deposit(address(strategyToken), amount, address(this), 0);
    }

    function _harvest(uint256 balance) internal override returns (int256 amountAdded) {
        uint256 currentBalance = IERC20(aToken).safeBalanceOf(address(this));
        amountAdded = int256(currentBalance) - int256(balance);
        if (amountAdded > 0) aaveLendingPool.withdraw(address(strategyToken), currentBalance - balance, address(this));
    }

    function _withdraw(uint256 amount) internal override {
        aaveLendingPool.withdraw(address(strategyToken), amount, address(this));
    }

    function _exit() internal override {
        uint256 tokenBalance = aToken.safeBalanceOf(address(this));
        uint256 available = strategyToken.safeBalanceOf(address(aToken));
        if (tokenBalance <= available) {
            /// @dev If there are more tokens available than our full position, take all based on aToken balance (continue if unsuccessful).
            try aaveLendingPool.withdraw(address(strategyToken), tokenBalance, address(this)) {} catch {}
        } else {
            /// @dev Otherwise redeem all available and take a loss on the missing amount (continue if unsuccessful).
            try aaveLendingPool.withdraw(address(strategyToken), available, address(this)) {} catch {}
        }
    }

    function _harvestRewards() internal override {
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = address(aToken);
        uint256 reward = incentiveController.getRewardsBalance(rewardTokens, address(this));
        incentiveController.claimRewards(rewardTokens, reward, address(this));
    }
}
