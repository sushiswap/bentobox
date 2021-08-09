// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../interfaces/IStrategy.sol";
import "../../interfaces/IBentoBoxMinimal.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";
import "@sushiswap/core/contracts/uniswapv2/libraries/UniswapV2Library.sol";

// solhint-disable avoid-low-level-calls
// solhint-disable not-rely-on-time
// solhint-disable no-empty-blocks
// solhint-disable avoid-tx-origin

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

interface IaToken {
    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);

    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function withdraw(
        address token,
        uint256 amount,
        address destination
    ) external;
}

interface IStakedAave {
    function stake(address to, uint256 amount) external;

    function redeem(address to, uint256 amount) external;

    function cooldown() external;

    function claimRewards(address to, uint256 amount) external;
}

contract AaveStrategy is IStrategy, BoringOwnable {
    using BoringMath for uint256;
    using BoringERC20 for IERC20;
    using BoringERC20 for IaToken;

    address public immutable aave;
    address public immutable aToken;
    IBentoBoxMinimal public immutable bentobox;
    address public immutable factory;
    address public immutable underlying;
    bool public exited;
    uint256 public maxBentoBalance;

    event LogConvert(address indexed server, address indexed token0, address indexed token1, uint256 amount0, uint256 amount1);

    constructor(
        address aave_,
        address factory_,
        IBentoBoxMinimal bentobox_,
        address underlying_
    ) public {
        aave = aave_;
        factory = factory_;
        bentobox = bentobox_;
        underlying = underlying_;
        IERC20(underlying_).approve(aave_, type(uint256).max);
        aToken = IaToken(aave_).getReserveData(underlying_).aTokenAddress;
    }

    modifier onlyBentobox() {
        // @dev Only the bentobox can call harvest on this strategy.
        require(msg.sender == address(bentobox), "AaveStrategy: only bento");
        require(!exited, "AaveStrategy: exited");
        _;
    }

    /// **** REWARD MGMT **** ///
    function cooldown(IStakedAave stkAave) external {
        stkAave.cooldown();
    }

    function stake(IStakedAave stkAave, uint256 amount) external {
        stkAave.stake(address(this), amount);
    }

    function redeem(IStakedAave stkAave, uint256 amount) external {
        stkAave.redeem(address(this), amount);
    }

    function claimRewards(IStakedAave stkAave, uint256 amount) external {
        stkAave.claimRewards(address(this), amount);
    }

    /// **** ///

    /// @notice Send the assets to the Strategy and call skim to invest them.
    /// @inheritdoc IStrategy
    function skim(uint256 amount) external override onlyBentobox {
        IaToken(aave).deposit(underlying, amount, address(this), 0);
    }

    function safeHarvest(
        uint256 maxBentoTokenShare,
        bool rebalance,
        uint256 maxChangeAmount
    ) external onlyOwner {
        maxBentoBalance = maxBentoTokenShare;
        bentobox.harvest(underlying, rebalance, maxChangeAmount);
    }

    /// @notice Harvest any profits made converted to the asset and pass them to the caller.
    /// @inheritdoc IStrategy
    function harvest(uint256 balance, address sender) public override onlyBentobox returns (int256 amountAdded) {
        // do not revert if conditions fail
        if (sender == address(this) && IBentoBoxMinimal(bentobox).totals(underlying).elastic <= maxBentoBalance) {
            // @dev Get the amount of tokens that the aTokens currently represent.
            uint256 tokenBalance = IERC20(aToken).safeBalanceOf(address(this));
            // @dev Convert enough aToken to take out the profit.
            // If the amount is negative due to rounding (near impossible), just revert (should be positive soon enough).
            IaToken(aave).withdraw(underlying, tokenBalance.sub(balance), address(this));
            uint256 amountAdded_ = IERC20(underlying).safeBalanceOf(address(this));
            // @dev Transfer the profit to the bentobox, the amountAdded at this point matches the amount transferred.
            IERC20(underlying).safeTransfer(address(bentobox), amountAdded_);
            maxBentoBalance = 0; // nullify maxShare
            return int256(amountAdded_);
        }

        return 0;
    }

    /// @notice Withdraw assets.
    /// @inheritdoc IStrategy
    function withdraw(uint256 amount) external override onlyBentobox returns (uint256 actualAmount) {
        // @dev Convert enough aToken to take out 'amount' tokens.
        IaToken(aave).withdraw(underlying, amount, address(this));
        // @dev Make sure we send and report the exact same amount of tokens by using balanceOf.
        actualAmount = IERC20(underlying).safeBalanceOf(address(this));
        IERC20(underlying).safeTransfer(address(bentobox), actualAmount);
    }

    /// @notice Withdraw all assets in the safest way possible - this shouldn't fail.
    /// @inheritdoc IStrategy
    function exit(uint256 balance) external override onlyBentobox returns (int256 amountAdded) {
        // @dev Get the amount of tokens that the aTokens currently represent.
        uint256 tokenBalance = IERC20(aToken).safeBalanceOf(address(this));
        // @dev Get the actual token balance of the aToken contract.
        uint256 available = IERC20(underlying).safeBalanceOf(aToken);
        // @dev Check that the aToken contract has enough balance to pay out in full.
        if (tokenBalance <= available) {
            // @dev If there are more tokens available than our full position, take all based on aToken balance (continue if unsuccessful).
            try IaToken(aave).withdraw(underlying, tokenBalance, address(this)) {} catch {}
        } else {
            // @dev Otherwise redeem all available and take a loss on the missing amount (continue if unsuccessful).
            try IaToken(aave).withdraw(underlying, available, address(this)) {} catch {}
        }
        // @dev Check balance of token on the contract.
        uint256 amount = IERC20(underlying).safeBalanceOf(address(this));
        // @dev Calculate tokens added (or lost).
        amountAdded = int256(amount) - int256(balance);
        // @dev Transfer all tokens to bentobox.
        IERC20(underlying).safeTransfer(address(bentobox), amount);
        // @dev Flag as exited, allowing the owner to manually deal with any amounts available later.
        exited = true;
    }

    function afterExit(
        address to,
        uint256 value,
        bytes memory data
    ) public onlyOwner returns (bool success) {
        // @dev After exited, the owner can perform ANY call. This is to rescue any funds that didn't get released during exit or
        // got earned afterwards due to vesting or airdrops, etc.
        require(exited, "AaveStrategy: not exited");
        (success, ) = to.call{value: value}(data);
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function swapExactTokensForTokens(uint256 amountOutMin, address[] calldata path) public onlyOwner returns (uint256[] memory amounts) {
        uint256 amountIn = IERC20(path[0]).safeBalanceOf(address(this));
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "AaveStrategy: insufficient output");
        IERC20(path[0]).safeTransfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));
        emit LogConvert(msg.sender, path[0], path[path.length - 1], amountIn, amounts[amounts.length - 1]);
    }

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
