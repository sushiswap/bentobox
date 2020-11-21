// Using the same Copyleft License as in the original Repository
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
import "../interfaces/IOracle.sol";
import "../libraries/BoringMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/lib/contracts/libraries/FixedPoint.sol";

// adapted from https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/examples/ExampleSlidingWindowOracle.sol

contract SimpleSLPOracle is IOracle {
    using FixedPoint for *;
    using BoringMath for uint;
    uint256 public constant PERIOD = 1 minutes;

    struct PairInfo {
      IUniswapV2Pair pair;
      bool isToken0;
      uint priceCumulativeLast;
      uint32 blockTimestampLast;
      FixedPoint.uq112x112 priceAverage;
    }

    mapping(address => PairInfo) public pairs; // Map of pairs and their info

    // helper function that returns the current block timestamp within the range of uint32, i.e. [0, 2**32 - 1]
    function currentBlockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp % 2 ** 32);
    }

    // produces the cumulative price using counterfactuals to save gas and avoid a call to sync.
    function currentCumulativePrices(
        address uniPair
    ) internal view returns (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) {
        blockTimestamp = currentBlockTimestamp();
        price0Cumulative = IUniswapV2Pair(uniPair).price0CumulativeLast();
        price1Cumulative = IUniswapV2Pair(uniPair).price1CumulativeLast();

        // if time has elapsed since the last update on the pair, mock the accumulated price values
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast0) = IUniswapV2Pair(uniPair).getReserves();
        if (blockTimestampLast0 != blockTimestamp) {
            // subtraction overflow is desired
            uint32 timeElapsed = blockTimestamp - blockTimestampLast0;
            // addition overflow is desired
            // counterfactual
            price0Cumulative += uint(FixedPoint.fraction(reserve1, reserve0)._x) * timeElapsed;
            // counterfactual
            price1Cumulative += uint(FixedPoint.fraction(reserve0, reserve1)._x) * timeElapsed;
        }
    }

    function init(address pair, address collateral) public {
        IUniswapV2Pair _pair = IUniswapV2Pair(pair);
        address tokenA = _pair.token0();
        address tokenB = _pair.token1();
        address token0;
        token0 = tokenA < tokenB ? tokenA : tokenB;

        pairs[msg.sender].pair = _pair;
        if (collateral == token0) {
            pairs[msg.sender].isToken0 = true;
            pairs[msg.sender].priceCumulativeLast = _pair.price0CumulativeLast();
        } else {
            pairs[msg.sender].isToken0 = false;
            pairs[msg.sender].priceCumulativeLast = _pair.price1CumulativeLast();
        }
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1, pairs[msg.sender].blockTimestampLast) = _pair.getReserves();
        require(reserve0 != 0 && reserve1 != 0, 'SimpleSLPOracle: NO_RESERVES'); // ensure that there's liquidity in the pair
    }

    function getInitData(address pair, address collateral) public pure returns (bytes memory) {
        return abi.encodeWithSignature("init(address,address)", pair, collateral);
    }

    function update(address bentoPair) public {
        (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) = currentCumulativePrices(address(pairs[bentoPair].pair));
        uint32 timeElapsed = blockTimestamp - pairs[bentoPair].blockTimestampLast; // overflow is desired

        // ensure that at least one full period has passed since the last update
        require(timeElapsed >= PERIOD, 'SimpleSLPOracle: PERIOD_NOT_ELAPSED');

        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        if(pairs[bentoPair].isToken0){
          pairs[bentoPair].priceAverage = FixedPoint.uq112x112(uint224((price0Cumulative - pairs[bentoPair].priceCumulativeLast) / timeElapsed));
          pairs[bentoPair].priceCumulativeLast = price0Cumulative;
        } else {
          pairs[bentoPair].priceAverage = FixedPoint.uq112x112(uint224((price1Cumulative - pairs[bentoPair].priceCumulativeLast) / timeElapsed));
          pairs[bentoPair].priceCumulativeLast = price1Cumulative;
        }
        pairs[bentoPair].blockTimestampLast = blockTimestamp;
    }

    // Get the latest exchange rate, if no valid (recent) rate is available, return false
    function get(address bentoPairAddress) external override returns (bool status, uint256 amountOut){
      uint32 blockTimestamp = currentBlockTimestamp();
      uint32 timeElapsed = blockTimestamp - pairs[bentoPairAddress].blockTimestampLast; // overflow is desired
      if(timeElapsed >= PERIOD){
        update(bentoPairAddress);
      }
      status = true;
      amountOut = peek(bentoPairAddress);
    }

    // Check the last exchange rate without any state changes
    function peek(address bentoPairAddress) public view override returns (uint256 amountOut) {
      amountOut = pairs[bentoPairAddress].priceAverage.mul(10**18).decode144();
    }

}
