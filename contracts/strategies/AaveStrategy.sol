// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "https://github.com/sushiswap/bentobox/blob/master/contracts/interfaces/IStrategy.sol";
import "https://github.com/sushiswap/sushiswap/blob/master/contracts/uniswapv2/interfaces/IUniswapV2Factory.sol";
import "https://github.com/sushiswap/sushiswap/blob/master/contracts/uniswapv2/interfaces/IUniswapV2Pair.sol";
import "https://github.com/boringcrypto/BoringSolidity/blob/master/contracts/BoringOwnable.sol";
import "https://github.com/boringcrypto/BoringSolidity/blob/master/contracts/libraries/BoringMath.sol";
import "https://github.com/boringcrypto/BoringSolidity/blob/master/contracts/libraries/BoringERC20.sol";
import "https://github.com/sushiswap/sushiswap/blob/master/contracts/uniswapv2/libraries/UniswapV2Library.sol";

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

// File @boringcrypto/boring-solidity/contracts/libraries/BoringRebase.sol@v1.2.0
// License-Identifier: MIT

struct Rebase {
    uint128 elastic;
    uint128 base;
}

/// @notice A rebasing library using overflow-/underflow-safe math.
library RebaseLibrary {
    using BoringMath for uint256;
    using BoringMath128 for uint128;

    /// @notice Calculates the base value in relationship to `elastic` and `total`.
    function toBase(
        Rebase memory total,
        uint256 elastic,
        bool roundUp
    ) internal pure returns (uint256 base) {
        if (total.elastic == 0) {
            base = elastic;
        } else {
            base = elastic.mul(total.base) / total.elastic;
            if (roundUp && base.mul(total.elastic) / total.base < elastic) {
                base = base.add(1);
            }
        }
    }

    /// @notice Calculates the elastic value in relationship to `base` and `total`.
    function toElastic(
        Rebase memory total,
        uint256 base,
        bool roundUp
    ) internal pure returns (uint256 elastic) {
        if (total.base == 0) {
            elastic = base;
        } else {
            elastic = base.mul(total.elastic) / total.base;
            if (roundUp && elastic.mul(total.base) / total.elastic < base) {
                elastic = elastic.add(1);
            }
        }
    }

    /// @notice Add `elastic` to `total` and doubles `total.base`.
    /// @return (Rebase) The new total.
    /// @return base in relationship to `elastic`.
    function add(
        Rebase memory total,
        uint256 elastic,
        bool roundUp
    ) internal pure returns (Rebase memory, uint256 base) {
        base = toBase(total, elastic, roundUp);
        total.elastic = total.elastic.add(elastic.to128());
        total.base = total.base.add(base.to128());
        return (total, base);
    }

    /// @notice Sub `base` from `total` and update `total.elastic`.
    /// @return (Rebase) The new total.
    /// @return elastic in relationship to `base`.
    function sub(
        Rebase memory total,
        uint256 base,
        bool roundUp
    ) internal pure returns (Rebase memory, uint256 elastic) {
        elastic = toElastic(total, base, roundUp);
        total.elastic = total.elastic.sub(elastic.to128());
        total.base = total.base.sub(base.to128());
        return (total, elastic);
    }

    /// @notice Add `elastic` and `base` to `total`.
    function add(
        Rebase memory total,
        uint256 elastic,
        uint256 base
    ) internal pure returns (Rebase memory) {
        total.elastic = total.elastic.add(elastic.to128());
        total.base = total.base.add(base.to128());
        return total;
    }

    /// @notice Subtract `elastic` and `base` to `total`.
    function sub(
        Rebase memory total,
        uint256 elastic,
        uint256 base
    ) internal pure returns (Rebase memory) {
        total.elastic = total.elastic.sub(elastic.to128());
        total.base = total.base.sub(base.to128());
        return total;
    }

    /// @notice Add `elastic` to `total` and update storage.
    /// @return newElastic Returns updated `elastic`.
    function addElastic(Rebase storage total, uint256 elastic) internal returns (uint256 newElastic) {
        newElastic = total.elastic = total.elastic.add(elastic.to128());
    }

    /// @notice Subtract `elastic` from `total` and update storage.
    /// @return newElastic Returns updated `elastic`.
    function subElastic(Rebase storage total, uint256 elastic) internal returns (uint256 newElastic) {
        newElastic = total.elastic = total.elastic.sub(elastic.to128());
    }
}

/// @notice Minimal interface for BentoBox token vault interactions - `token` is aliased as `address` from `IERC20` for code simplicity.
interface IBentoBoxMinimal {
    /// @notice Balance per ERC-20 token per account in shares.
    function balanceOf(address, address) external view returns (uint256);

    /// @notice Deposit an amount of `token` represented in either `amount` or `share`.
    /// @param token_ The ERC-20 token to deposit.
    /// @param from which account to pull the tokens.
    /// @param to which account to push the tokens.
    /// @param amount Token amount in native representation to deposit.
    /// @param share Token amount represented in shares to deposit. Takes precedence over `amount`.
    /// @return amountOut The amount deposited.
    /// @return shareOut The deposited amount repesented in shares.
    function deposit(
        address token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external payable returns (uint256 amountOut, uint256 shareOut);

    /// @notice Withdraws an amount of `token` from a user account.
    /// @param token_ The ERC-20 token to withdraw.
    /// @param from which user to pull the tokens.
    /// @param to which user to push the tokens.
    /// @param amount of tokens. Either one of `amount` or `share` needs to be supplied.
    /// @param share Like above, but `share` takes precedence over `amount`.
    function withdraw(
        address token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external returns (uint256 amountOut, uint256 shareOut);

    /// @notice Transfer shares from a user account to another one.
    /// @param token The ERC-20 token to transfer.
    /// @param from which user to pull the tokens.
    /// @param to which user to push the tokens.
    /// @param share The amount of `token` in shares.
    function transfer(
        address token,
        address from,
        address to,
        uint256 share
    ) external;

    /// @dev Helper function to represent an `amount` of `token` in shares.
    /// @param token The ERC-20 token.
    /// @param amount The `token` amount.
    /// @param roundUp If the result `share` should be rounded up.
    /// @return share The token amount represented in shares.
    function toShare(
        address token,
        uint256 amount,
        bool roundUp
    ) external view returns (uint256 share);

    /// @dev Helper function to represent shares back into the `token` amount.
    /// @param token The ERC-20 token.
    /// @param share The amount of shares.
    /// @param roundUp If the result should be rounded up.
    /// @return amount The share amount back into native representation.
    function toAmount(
        address token,
        uint256 share,
        bool roundUp
    ) external view returns (uint256 amount);

    /// @notice Registers this contract so that users can approve it for the BentoBox.
    function registerProtocol() external;
    
    function totals(address token) external view returns (Rebase memory);
    
    function harvest(
        address token,
        bool balance,
        uint256 maxChangeAmount
    ) external;
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
    uint256 public maxShare;
    
    event LogConvert(
        address indexed server,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1
    );

    constructor(
        address aave_,
        address factory_,
        IBentoBoxMinimal bentobox_,
        address underlying_
    ) public {
        aave = aave_;
        bentobox = bentobox_;
        factory = factory_;
        underlying = underlying_;
        IERC20(underlying_).approve(aave_, type(uint256).max);
        aToken = IaToken(aave_).getReserveData(underlying_).aTokenAddress;
    }

    modifier onlyBentobox {
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
    
    function preHarvest(uint256 maxBentoTokenShare, bool balance, uint256 maxChangeAmount) external onlyOwner {
        maxShare = maxBentoTokenShare;
        bentobox.harvest(underlying, balance, maxChangeAmount);
    }

    /// @notice Send the assets to the Strategy and call skim to invest them.
    /// @inheritdoc IStrategy
    function skim(uint256 amount) external override onlyBentobox {
        IaToken(aave).deposit(underlying, amount, address(this), 0);
    }

    /// @notice Harvest any profits made converted to the asset and pass them to the caller.
    /// @inheritdoc IStrategy
    function harvest(uint256 balance, address sender) public override onlyBentobox returns (int256 amountAdded) {
        // @dev To prevent anyone from using flash loans to 'steal' part of the profits, only EOA is allowed to call harvest.
        require(sender == owner, "AaveStrategy: not owner"); // permission check
        require(IBentoBoxMinimal(bentobox).totals(underlying).elastic <= maxShare, "AaveStrategy: mmm sandwiched"); // sandwich check
        // @dev Get the amount of tokens that the aTokens currently represent.
        uint256 tokenBalance = IERC20(aToken).safeBalanceOf(address(this));
        // @dev Convert enough aToken to take out the profit.
        // If the amount is negative due to rounding (near impossible), just revert (should be positive soon enough).
        IaToken(aave).withdraw(underlying, tokenBalance.sub(balance), address(this));
        uint256 amountAdded_ = IERC20(underlying).safeBalanceOf(address(this));
        // @dev Transfer the profit to the bentobox, the amountAdded at this point matches the amount transferred.
        IERC20(underlying).safeTransfer(address(bentobox), amountAdded_);
        maxShare = 0; // nullify maxShare
        return int256(amountAdded_);
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
        require(exited, "AaveStrategy: Not exited");
        (success, ) = to.call{value: value}(data);
    }
    
    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function swapExactTokensForTokens(
        uint256 amountOutMin,
        address[] calldata path
    ) public onlyOwner returns (uint256[] memory amounts) {
        uint256 amountIn = IERC20(path[0]).safeBalanceOf(address(this));
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IERC20(path[0]).safeTransfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));
        emit LogConvert(
            msg.sender,
            path[0],
            path[path.length - 1],
            amountIn,
            amounts[amounts.length - 1]
        );
    }
    
    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
}
