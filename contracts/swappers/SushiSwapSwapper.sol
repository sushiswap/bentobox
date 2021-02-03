// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@sushiswap/core/contracts/uniswapv2/interfaces/IUniswapV2Factory.sol";
import "@sushiswap/core/contracts/uniswapv2/interfaces/IUniswapV2Pair.sol";
import "@boringcrypto/boring-solidity/contracts/interfaces/IERC20.sol";
import "../interfaces/ISwapper.sol";
import "../BentoBoxPlus.sol";

contract SushiSwapSwapper is ISwapper {
    using BoringMath for uint256;

    // Local variables
    BentoBoxPlus public bentoBox;
    IUniswapV2Factory public factory;

    constructor(BentoBoxPlus bentoBox_, IUniswapV2Factory factory_) public {
        bentoBox = bentoBox_;
        factory = factory_;
    }
    // Given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn.mul(997);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // Given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256 amountIn) {
        uint256 numerator = reserveIn.mul(amountOut).mul(1000);
        uint256 denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    // Swaps to a flexible amount, from an exact input amount
    function swap(
        IERC20 fromToken, IERC20 toToken, address recipient, uint256 amountToMin, uint256 shareFrom
    ) public override returns (uint256 extraAmount, uint256 shareTo) {
        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(address(fromToken), address(toToken)));

        (uint256 amountFrom, ) = bentoBox.withdraw(fromToken, address(this), address(pair), 0, shareFrom);

        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
        uint256 amountTo;
        if (pair.token0() == address(fromToken)) {
            amountTo = getAmountOut(amountFrom, reserve0, reserve1);
            pair.swap(0, amountTo, address(bentoBox), new bytes(0));
        } else {
            amountTo = getAmountOut(amountFrom, reserve1, reserve0);
            pair.swap(amountTo, 0, address(bentoBox), new bytes(0));
        }
        extraAmount = amountTo.sub(amountToMin);
        (, shareTo) = bentoBox.deposit(toToken, address(bentoBox), recipient, amountTo, 0);
    }

    // Swaps to an exact amount, from a flexible input amount
    function swapExact(
        IERC20 fromToken, IERC20 toToken, address recipient, address refundTo, uint256 shareFromSupplied, uint256 shareToExact
    ) public override returns (uint256 shareUsed, uint256 shareReturned) {
        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(address(fromToken), address(toToken)));
        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();

        uint256 amountToExact = bentoBox.toAmount(toToken, shareToExact, true);

        uint256 amountFrom;
        if (pair.token0() == address(fromToken)) {
            amountFrom = getAmountIn(amountToExact, reserve0, reserve1);
            (, shareUsed) = bentoBox.withdraw(fromToken, address(this), address(pair), amountFrom, 0);
            pair.swap(0, amountToExact, address(bentoBox), "");
        } else {
            amountFrom = getAmountIn(amountToExact, reserve1, reserve0);
            (, shareUsed) = bentoBox.withdraw(fromToken, address(this), address(pair), amountFrom, 0);
            pair.swap(amountToExact, 0, address(bentoBox), "");
        }
        bentoBox.deposit(toToken, address(bentoBox), recipient, 0, shareToExact);
        shareReturned = shareFromSupplied.sub(shareUsed);
        bentoBox.transfer(fromToken, address(this), refundTo, shareReturned);
    }
}
