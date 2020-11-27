// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;
import "../libraries/BoringMath.sol";
import "../libraries/Ownable.sol";
import "../external/SushiSwapFactory.sol";
import "../BentoBox.sol";
import "../ERC20.sol";
import "../interfaces/ISwapper.sol";

contract SushiSwapSwapper is ISwapper {
    using BoringMath for uint256;

    // Local variables
    BentoBox public bentoBox;
    IUniswapV2Factory public factory;

    constructor(BentoBox bentoBox_, IUniswapV2Factory factory_) public {
        bentoBox = bentoBox_;
        factory = factory_;
    }
    // Given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // Given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    // Swaps to a flexible amount, from an exact input amount
    function swap(IERC20 from, IERC20 to, uint256 amountFrom, uint256 amountToMin) public override returns (uint256) {
        UniswapV2Pair pair = UniswapV2Pair(factory.getPair(address(from), address(to)));

        bentoBox.withdraw(from, address(pair), amountFrom);

        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
        uint256 amountTo;
        if (pair.token0() == address(from)) {
            amountTo = getAmountOut(amountFrom, reserve0, reserve1);
            require(amountTo >= amountToMin, 'SushiSwapClosedSwapper: return not enough');
            pair.swap(0, amountTo, address(bentoBox), new bytes(0));
        } else {
            amountTo = getAmountOut(amountFrom, reserve1, reserve0);
            require(amountTo >= amountToMin, 'SushiSwapClosedSwapper: return not enough');
            pair.swap(amountTo, 0, address(bentoBox), new bytes(0));
        }
        return amountTo;
    }

    // Swaps to an exact amount, from a flexible input amount
    function swapExact(IERC20 from, IERC20 to, uint256 amountFromMax, uint256 exactAmountTo, address refundTo) public override returns (uint256) {
        UniswapV2Pair pair = UniswapV2Pair(factory.getPair(address(from), address(to)));

        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();

        uint256 amountFrom;
        if (pair.token0() == address(from)) {
            amountFrom = getAmountIn(exactAmountTo, reserve0, reserve1);
            require(amountFrom <= amountFromMax, 'SushiSwapClosedSwapper: return not enough');
            bentoBox.withdraw(from, address(pair), amountFrom);
            pair.swap(0, exactAmountTo, address(bentoBox), new bytes(0));
        } else {
            amountFrom = getAmountIn(exactAmountTo, reserve1, reserve0);
            require(amountFrom <= amountFromMax, 'SushiSwapClosedSwapper: return not enough');
            bentoBox.withdraw(from, address(pair), amountFrom);
            pair.swap(exactAmountTo, 0, address(bentoBox), new bytes(0));
        }

        bentoBox.transferFrom(from, address(this), refundTo, amountFromMax.sub(amountFrom));

        return amountFrom;
    }
}
