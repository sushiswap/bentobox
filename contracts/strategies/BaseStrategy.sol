// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../interfaces/IStrategy.sol";
import "../interfaces/IBentoBoxMinimal.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";
import "@sushiswap/core/contracts/uniswapv2/libraries/UniswapV2Library.sol";

//// @title Base contract which custom BentoBox strategies should extend.
//// @notice Abstract BentoBox interactions away from the strategy implementation. Minimizes risk of sandwich attacks.
//// @dev Implement _skim, _harvest, _withdraw and _exit functions in your strategy.
abstract contract BaseStrategy is IStrategy, BoringOwnable {
    using BoringMath for uint256;
    using BoringERC20 for IERC20;

    struct BaseStrategyParams {
        IERC20 underlying;
        IBentoBoxMinimal bentoBox;
        address strategyExecutor;
        address factory;
        address bridgeToken;
    }

    IERC20 public immutable underlying;
    IBentoBoxMinimal public immutable bentoBox;
    address public immutable factory;
    address public immutable bridgeToken;

    bool public exited;
    uint256 public maxBentoBoxBalance;
    mapping(address => bool) public strategyExecutors;

    event LogConvert(address indexed server, address indexed token0, address indexed token1, uint256 amount0, uint256 amount1);
    event LogSetStrategyExecutor(address indexed executor, bool allowed);

    /** @param baseStrategyParams.underlying Token the strategy invests.
        @param baseStrategyParams.bentoBox BentoBox address.
        @param baseStrategyParams.strategyExecutor EOA that will execute the safeHarvest function.
        @param baseStrategyParams.factory SushiSwap factory.
        @param baseStrategyParams.bridgeToken An intermedieary token for swapping any rewards into the underlying token.*/
    constructor(BaseStrategyParams memory baseStrategyParams) public {
        underlying = baseStrategyParams.underlying;
        bentoBox = baseStrategyParams.bentoBox;
        strategyExecutors[baseStrategyParams.strategyExecutor] = true;
        factory = baseStrategyParams.factory;
        bridgeToken = baseStrategyParams.bridgeToken;
    }

    //** Strategy implementation: override the following functions: */

    /// @notice Invests the underlying asset.
    /// @param amount The amount of tokens to invest.
    /// @dev Assume the contract's balance is greater than the amount
    function _skim(uint256 amount) internal virtual;

    /// @notice Harvest any profits made and transfer them to address(this) or report a loss
    /// @param balance The amount of tokens that have been invested.
    /// @return amountAdded The delta (+profit or -loss) that occured in contrast to `balance`.
    /// @dev amountAdded can be left at 0 when reporting profits (gas savings).
    /// @dev amountAdded shouldn't reflect any rewards the strategy received.
    function _harvest(uint256 balance) internal virtual returns (int256 amountAdded);

    /// @notice Claim any rewards reward tokens and optionally sell them for the underlying token.
    /// @dev Doesn't need to be implemented if we don't expect any rewards.
    function _harvestRewards() internal virtual {}

    /// @dev Withdraw the requested amount of the underlying tokens to address(this).
    /// @param amount The requested amount we want to withdraw.
    function _withdraw(uint256 amount) internal virtual;

    /// @notice Withdraw the maximum amount of the invested assets to address(this).
    /// @dev This shouldn't revert (use try catch).
    function _exit() internal virtual;

    //** End strategy implementation */

    modifier onlyBentobox() {
        require(msg.sender == address(bentoBox), "BentoBox Strategy: only bento");
        require(!exited, "BentoBox Strategy: exited");
        _;
    }

    modifier onlyExecutor() {
        require(strategyExecutors[msg.sender], "BentoBox Strategy: only executor");
        _;
    }

    function setStrategyExecutor(address executor, bool value) external onlyOwner {
        strategyExecutors[executor] = value;
        emit LogSetStrategyExecutor(executor, strategyExecutors[executor]);
    }

    /// @inheritdoc IStrategy
    function skim(uint256 amount) external override {
        _skim(amount);
    }

    /// @notice Harvest profits while preventing a sandwich attack exploit.
    /// @param maxBalance The maximum balance of the underlying token that is allowed to be in BentoBox.
    /// @param rebalance Whether BentoBox should rebalance the strategy assets to acheive it's target allocation.
    /// @param maxChangeAmount When rebalancing - the maximum amount that will be deposited to or withdrawn from a strategy.
    /// @param harvestRewards Whether we should also harvest any rewards for the strategy;
    /// @dev maxBalance can be set to 0 to keep the previous value.
    /// @dev maxChangeAmount can be set to 0 to allow for full rebalancing.
    function safeHarvest(
        uint256 maxBalance,
        bool rebalance,
        uint256 maxChangeAmount,
        bool harvestRewards
    ) external onlyExecutor {
        if (harvestRewards) _harvestRewards();
        if (maxBalance > 0) maxBentoBoxBalance = maxBalance;
        bentoBox.harvest(address(underlying), rebalance, maxChangeAmount);
    }

    /** @inheritdoc IStrategy
    @dev Only BentoBox can call harvest on this strategy.
    @dev Ensures that (1) the caller was this contract (called through the safeHarvest function)
        and (2) that we are not being frontrun by a large BentoBox deposit when harvesting profits. */
    function harvest(uint256 balance, address sender) external override onlyBentobox returns (int256) {
        /** @dev Don't revert if conditions aren't met in order to allow
            BentoBox to continiue execution as it might need to do a rebalance. */
        if (sender == address(this) && IBentoBoxMinimal(bentoBox).totals(address(underlying)).elastic <= maxBentoBoxBalance) {
            
            /** We might also have some underlying tokens in the contract (e.g. bought from any received reward tokens)
                so the amount returned by the internal _harvest function isn't necessary the final profit/loss amount */
            int256 amount = _harvest(balance);

            uint256 contractBalance = IERC20(underlying).safeBalanceOf(address(this));

            if (amount >= 0) {
                // strategy made some profit
                if (contractBalance > 0) IERC20(underlying).safeTransfer(address(bentoBox), contractBalance);
                return int256(contractBalance);
            } else if (contractBalance > 0) {
                // strategy made a loss
                int256 diff = amount + int256(contractBalance);

                if (diff > 0) {
                    // we still made some profit due to rewards
                    _skim(uint256(-amount));
                    IERC20(underlying).safeTransfer(address(bentoBox), uint256(diff));
                    return diff;
                } else {
                    // we made a loss but we have some tokens we can reinvest
                    _skim(contractBalance);
                    return diff;
                }
            } else {
                // we made a loss
                return amount;
            }
        }
        return int256(0);
    }

    /// @inheritdoc IStrategy
    function withdraw(uint256 amount) external override onlyBentobox returns (uint256 actualAmount) {
        _withdraw(amount);
        /// @dev Make sure we send and report the exact same amount of tokens by using balanceOf.
        actualAmount = IERC20(underlying).safeBalanceOf(address(this));
        IERC20(underlying).safeTransfer(address(bentoBox), actualAmount);
    }

    /// @inheritdoc IStrategy
    function exit(uint256 balance) external override onlyBentobox returns (int256 amountAdded) {
        _exit();
        /// @dev Check balance of token on the contract.
        uint256 actualBalance = IERC20(underlying).safeBalanceOf(address(this));
        /// @dev Calculate tokens added (or lost).
        amountAdded = int256(actualBalance) - int256(balance);
        /// @dev Transfer all tokens to bentoBox.
        underlying.safeTransfer(address(bentoBox), actualBalance);
        /// @dev Flag as exited, allowing the owner to manually deal with any amounts available later.
        exited = true;
    }

    /** @dev After exited, the owner can perform ANY call. This is to rescue any funds that didn't
        get released during exit or got earned afterwards due to vesting or airdrops, etc. */
    function afterExit(
        address to,
        uint256 value,
        bytes memory data
    ) public onlyOwner returns (bool success) {
        require(exited, "BentoBox Strategy: not exited");
        (success, ) = to.call{value: value}(data);
    }

    /// @notice Swap some tokens in the contract for the underlying
    function swapExactTokensForUnderlying(uint256 amountOutMin, address reward, bool useBridge) public onlyExecutor returns (uint256[] memory amounts) {
        
        address[] memory path = new address[](useBridge ? 3 : 2);
        path[0] = reward;
        if (useBridge) path[1] = bridgeToken;
        path[path.length - 1] = address(underlying);

        uint256 amountIn = IERC20(path[0]).safeBalanceOf(address(this));
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "BentoBox Strategy: insufficient output");

        IERC20(path[0]).safeTransfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));

        emit LogConvert(msg.sender, path[0], path[path.length - 1], amountIn, amounts[amounts.length - 1]);
    }

    /// @dev requires the initial amount to have already been sent to the first pair
    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = UniswapV2Library.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output)).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
}