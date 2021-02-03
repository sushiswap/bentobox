// SPDX-License-Identifier: AGPL-3.0-only

// Using the same Copyleft License as in the original Repository
// solhint-disable not-rely-on-time

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "../interfaces/IOracle.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@sushiswap/core/contracts/uniswapv2/interfaces/IUniswapV2Factory.sol";
import "@sushiswap/core/contracts/uniswapv2/interfaces/IUniswapV2Pair.sol";
import "../libraries/FixedPoint.sol";

// adapted from https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/examples/ExampleSlidingWindowOracle.sol

contract SimpleSLPTWAP0Oracle is IOracle {
    using FixedPoint for *;
    using BoringMath for uint256;
    uint256 public constant PERIOD = 5 minutes;

    struct PairInfo {
        uint256 priceCumulativeLast;
        uint32 blockTimestampLast;
        FixedPoint.uq112x112 priceAverage;
    }

    mapping(IUniswapV2Pair => PairInfo) public pairs; // Map of pairs and their info
    mapping(address => IUniswapV2Pair) public callerInfo; // Map of callers to pairs

    function _get(IUniswapV2Pair pair, uint32 blockTimestamp) public view returns (uint256) {
        uint256 priceCumulative = pair.price0CumulativeLast();

        // if time has elapsed since the last update on the pair, mock the accumulated price values
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = IUniswapV2Pair(pair).getReserves();
        priceCumulative += uint256(FixedPoint.fraction(reserve1, reserve0)._x) * (blockTimestamp - blockTimestampLast); // overflows ok

        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        return priceCumulative;
    }

    function getDataParameter(IUniswapV2Pair pair) public pure returns (bytes memory) { return abi.encode(pair); }

    // Get the latest exchange rate, if no valid (recent) rate is available, return false
    function get(bytes calldata data) external override returns (bool, uint256) {
        IUniswapV2Pair pair = abi.decode(data, (IUniswapV2Pair));
        uint32 blockTimestamp = uint32(block.timestamp);
        if (pairs[pair].blockTimestampLast == 0) {
            pairs[pair].blockTimestampLast = blockTimestamp;
            pairs[pair].priceCumulativeLast = _get(pair, blockTimestamp);

            return (false, 0);
        }
        uint32 timeElapsed = blockTimestamp - pairs[pair].blockTimestampLast; // overflow is desired
        if (timeElapsed < PERIOD) {
            return (true, pairs[pair].priceAverage.mul(10**18).decode144());
        }

        uint256 priceCumulative = _get(pair, blockTimestamp);
        pairs[pair].priceAverage = FixedPoint.uq112x112(uint224((priceCumulative - pairs[pair].priceCumulativeLast) / timeElapsed));
        pairs[pair].blockTimestampLast = blockTimestamp;
        pairs[pair].priceCumulativeLast = priceCumulative;

        return (true, pairs[pair].priceAverage.mul(10**18).decode144());
    }

    // Check the last exchange rate without any state changes
    function peek(bytes calldata data) public override view returns (bool, uint256) {
        IUniswapV2Pair pair = abi.decode(data, (IUniswapV2Pair));
        uint32 blockTimestamp = uint32(block.timestamp);
        if (pairs[pair].blockTimestampLast == 0) {
            return (false, 0);
        }
        uint32 timeElapsed = blockTimestamp - pairs[pair].blockTimestampLast; // overflow is desired
        if (timeElapsed < PERIOD) {
            return (true, pairs[pair].priceAverage.mul(10**18).decode144());
        }

        uint256 priceCumulative = _get(pair, blockTimestamp);
        FixedPoint.uq112x112 memory priceAverage = FixedPoint
            .uq112x112(uint224((priceCumulative - pairs[pair].priceCumulativeLast) / timeElapsed));

        return (true, priceAverage.mul(10**18).decode144());
    }

    function name(bytes calldata) public override view returns (string memory) {
        return "SushiSwap TWAP";
    }

    function symbol(bytes calldata) public override view returns (string memory) {
        return "S";
    }
}
