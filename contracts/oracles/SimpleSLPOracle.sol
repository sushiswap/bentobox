// Using the same Copyleft License as in the original Repository
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.6.12;
import "../interfaces/IOracle.sol";
import "../interfaces/ILendingPair.sol";
import "../libraries/BoringMath.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/lib/contracts/libraries/FixedPoint.sol";

// adapted from https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/examples/ExampleSlidingWindowOracle.sol

contract SimpleSLPOracle is IOracle {
    using FixedPoint for *;
    using BoringMath for uint;
    uint256 public constant PERIOD = 1 minutes;
    IUniswapV2Pair pair;
    bool isToken0;
    uint    public price0CumulativeLast;
    uint    public price1CumulativeLast;
    uint32  public blockTimestampLast;
    FixedPoint.uq112x112 public priceAverage;

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

    function init(address factory) public {
        address bentoPairAddress = msg.sender;
        IPair bentoPair = IPair(bentoPairAddress);
        address token = address(bentoPair.asset());
        address collateral = address(bentoPair.collateral());
        IUniswapV2Pair _pair = IUniswapV2Pair(IUniswapV2Factory(factory).getPair(token, collateral));
        address tokenA = _pair.token0();
        address tokenB = _pair.token1();
        address token0;
        address token1;
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        price0CumulativeLast = _pair.price0CumulativeLast(); // fetch the current accumulated price value (1 / 0)
        price1CumulativeLast = _pair.price1CumulativeLast(); // fetch the current accumulated price value (0 / 1)
        pair = _pair;
        if (collateral == token0) {
            isToken0 = true;
        } else {
            isToken0 = false;
        }
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1, blockTimestampLast) = _pair.getReserves();
        require(reserve0 != 0 && reserve1 != 0, 'SimpleSLPOracle: NO_RESERVES'); // ensure that there's liquidity in the pair
    }

    function getInitData(address factory) public pure returns (bytes memory) {
        return abi.encodeWithSignature("init(address)", factory);
    }

    function update() public {
        (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) = currentCumulativePrices(address(pair));
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

        // ensure that at least one full period has passed since the last update
        require(timeElapsed >= PERIOD, 'SimpleSLPOracle: PERIOD_NOT_ELAPSED');

        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        if(isToken0){
          priceAverage = FixedPoint.uq112x112(uint224((price0Cumulative - price0CumulativeLast) / timeElapsed));
        } else {
          priceAverage = FixedPoint.uq112x112(uint224((price1Cumulative - price1CumulativeLast) / timeElapsed));
        }
        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast = blockTimestamp;
    }

    // Get the latest exchange rate, if no valid (recent) rate is available, return false
    function get(address bentoPairAddress) external override returns (bool status, uint256 amountOut){
      uint32 blockTimestamp = currentBlockTimestamp();
      uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
      if(timeElapsed >= PERIOD){
        update();
      }
      status = true;
      amountOut = peek(bentoPairAddress);
    }

    // Check the last exchange rate without any state changes
    function peek(address bentoPairAddress) public view override returns (uint256 amountOut) {
      IPair bentoPair = IPair(bentoPairAddress);
      amountOut = priceAverage.mul(10**18).decode144();
    }

}
