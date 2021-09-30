// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../BaseStrategy.sol";

interface IStakingPool {
    function deposit(uint256 _poolId, uint256 _depositAmount) external;
    function claim(uint256 _poolId) external;
    function withdraw(uint256 _poolId, uint256 _withdrawAmount) external;
    function getStakeTotalUnclaimed(address _account, uint256 _poolId) external view returns (uint256);
    function exit(uint256 _poolId) external;
}

contract ALCXStrategy is BaseStrategy {
    IStakingPool public constant STAKING_POOL = IStakingPool(0xAB8e74017a8Cc7c15FFcCd726603790d26d7DeCa);
    uint256 private constant POOL_ID = 1;

    constructor(BaseStrategyParams memory baseStrategyParams) public BaseStrategy(baseStrategyParams) {
        IERC20(baseStrategyParams.token).approve(address(STAKING_POOL), type(uint256).max);
    }

    function _skim(uint256 amount) internal override {
        STAKING_POOL.deposit(POOL_ID, amount);
    }

    function _harvest(uint256 balance) internal override returns (int256) {
        STAKING_POOL.claim(POOL_ID);
        // ALCX Staking Pool can't report a loss so no need to check for keep < total case
        return int256(0);
    }

    function _withdraw(uint256 amount) internal override {
        uint256 unclaimedRewards = STAKING_POOL.getStakeTotalUnclaimed(address(this), POOL_ID);
        uint256 withdrawAmount = amount.sub(unclaimedRewards);
        STAKING_POOL.withdraw(withdrawAmount);
    }

    function _exit() internal override {
        STAKING_POOL.exit(POOL_ID);
    }
}
