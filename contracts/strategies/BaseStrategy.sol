// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../interfaces/IStrategy.sol";
import "../interfaces/IBentoBoxMinimal.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";
import "@sushiswap/core/contracts/uniswapv2/libraries/UniswapV2Library.sol";

abstract contract BaseStrategy is IStrategy, BoringOwnable {
    
    using BoringMath for uint256;
    using BoringERC20 for IERC20;

    IERC20 public immutable underlying;
    IBentoBoxMinimal public immutable bentoBox;
    address public immutable factory;
    
    bool public exited;
    uint256 public maxBentoBoxBalance;
    mapping(address => bool) public strategyExecutors;
    mapping(bytes32 => bool) public allowedPaths;

    event LogConvert(address indexed server, address indexed token0, address indexed token1, uint256 amount0, uint256 amount1);
	event LogToggleStrategyExecutor(address indexed executor, bool allowed);

    /** @param _underlying Token the strategy invests.
        @param _bentoBox BentoBox address.
        @param _strategyExecutor EOA that will execute the safeHarvest function.
        @param _factory SushiSwap factory.
        @param _allowedPaths Allowed trade paths to trade from any reward token to the underlying. */
    constructor(
        IERC20 _underlying,
        IBentoBoxMinimal _bentoBox,
		address _strategyExecutor,
        address _factory,
		address[][] memory _allowedPaths
    ) public {
        
		underlying = _underlying;
        bentoBox = _bentoBox;
		strategyExecutors[_strategyExecutor] = true;
        factory = _factory;
		
		for (uint i = 0; i < _allowedPaths.length; i++) {
			allowedPaths[keccak256(abi.encodePacked(_allowedPaths[i]))] = true;
		}
    }

    modifier onlyBentobox {
        // @dev Only BentoBox can call harvest on this strategy.
        require(msg.sender == address(bentoBox), "BentoBox Strategy: only bento");
        require(!exited, "BentoBox Strategy: exited");
        _;
    }

	modifier onlyExecutor {
		// @dev Only executors can call safeHarvest on this strategy.
		require(strategyExecutors[msg.sender], "BentoBox Strategy: only executor");
		_;
	}

	function toggleStrategyExecutor(address executor) external onlyOwner {
		strategyExecutors[executor] = !strategyExecutors[executor];
		emit LogToggleStrategyExecutor(executor, strategyExecutors[executor]);
	}

    /// @inheritdoc IStrategy
    function skim(uint256 amount) external override {
		_skim(amount);
	}

	/// @notice Invests the underlying asset.
    /// @param amount The amount of tokens to invest.
    /// @dev Assume the contract's balance is greater than the amount
	function _skim(uint256 amount) internal virtual;

	/// @notice Harvest profits while preventing a sandwich attack exploit.
    /// @param maxBalance The maximum balance of the underlying token that is allowed to be in BentoBox.
    /// @param rebalance Whether BentoBox should rebalance the strategy assets to acheive it's target allocation.
    /// @param maxChangeAmount When rebalancing - the maximum amount that can be deposited or withdrawn from a strategy.
    /// @dev maxChangeAmount can be set to 0 to allow for full rebalancing.
    function safeHarvest(
        uint256 maxBalance,
        bool rebalance,
        uint256 maxChangeAmount
    ) external onlyExecutor {
        maxBentoBoxBalance = maxBalance;
        bentoBox.harvest(address(underlying), rebalance, maxChangeAmount);
    }

    /// @inheritdoc IStrategy
    function harvest(uint256 balance, address sender) external override onlyBentobox returns (int256) {

		/** @dev Ensures that (1) the caller was this contract (called through the safeHarvest function)
		    and (2) that we are not being frontrun by a large BentoBox deposit when harvesting profits.
		    @dev Don't revert if conditions aren't met in order to allow
		    BentoBox to continiue execution as it might need to do a rebalance. */
		if (sender == address(this) && IBentoBoxMinimal(bentoBox).totals(address(underlying)).elastic <= maxBentoBoxBalance) {


            /** @dev We might also have some underlying tokens in the contract from before so the amount
                returned by the internal _harvest function isn't necessary the final profit/loss amount */
            int256 amount = _harvest(balance);

            uint256 contractBalance = IERC20(underlying).safeBalanceOf(address(this));

            if (amount >= 0) {
                // we made some profit
                if (contractBalance > 0) {
                    IERC20(underlying).safeTransfer(address(bentoBox), contractBalance);
                }
                return int256(contractBalance);

            } else if (contractBalance > 0) {
                // we might have made a loss
                int256 diff = amount + int256(contractBalance);
                    
                if (diff > 0) {
                    // we still made some profit
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

	/// @notice Harvest any profits made and transfer them to address(this) or report a loss
    /// @param balance The amount of tokens that have been invested.
    /// @return amountAdded The delta (+profit or -loss) that occured in contrast to `balance`.
    /// @dev amountAdded can be left at 0 when reporting profits (gas savings).
	function _harvest(uint256 balance) internal virtual returns (int256 amountAdded);

    /// @inheritdoc IStrategy
    function withdraw(uint256 amount) external override onlyBentobox returns (uint256 actualAmount) {
        _withdraw(amount);
        /// @dev Make sure we send and report the exact same amount of tokens by using balanceOf.
        actualAmount = IERC20(underlying).safeBalanceOf(address(this));
        IERC20(underlying).safeTransfer(address(bentoBox), actualAmount);
    }

	/// @dev Withdraw the requested amount of the underlying tokens to address(this)
	/// @param amount The requested amount the caller wants to withdraw.
	function _withdraw(uint256 amount) internal virtual;

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

	/// @notice Withdraw the maximum amount of the invested assets to address(this).
	/// @dev This shouldn't revert (use try catch).
	function _exit() internal virtual;

    function afterExit(
        address to,
        uint256 value,
        bytes memory data
    ) public onlyOwner returns (bool success) {
        /** @dev After exited, the owner can perform ANY call. This is to rescue any funds that didn't
			get released during exit or got earned afterwards due to vesting or airdrops, etc. */
        require(exited, "BentoBox Strategy: not exited");
        (success, ) = to.call{value: value}(data);
    }

    // **** SWAP ****
	/// @notice Swap some tokens in the contract
	function swapExactTokensForTokens(
		uint256 amountOutMin,
		address[] calldata path
	) public onlyExecutor returns (uint256[] memory amounts) {

		/// @dev prevent the owner from siphoning off profits by swapping through an illiquid path
		require(allowedPaths[keccak256(abi.encodePacked(path))] || exited, "BentoBox Strategy: monkey business");
		
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
