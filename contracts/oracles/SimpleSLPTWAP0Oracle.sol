// Using the same Copyleft License as in the original Repository
// SPDX-License-Identifier: AGPL-3.0-only
// solium-disable security/no-block-members

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "../interfaces/IOracle.sol";
import "../libraries/BoringMath.sol";
import "../external/interfaces/IUniswapV2Factory.sol";
import "../external/interfaces/IUniswapV2Pair.sol";
import "../libraries/FixedPoint.sol";

// adapted from https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/examples/ExampleSlidingWindowOracle.sol

contract SimpleSLPTWAP0Oracle is IOracle {
    using FixedPoint for *;
    using BoringMath for uint256;
    uint256 public constant PERIOD = 20; // min blocks between updates

    struct PairInfo {
        uint256 priceCumulativeLast;
        uint32 blockHeightLast;
        uint32 blockTimestampLast;
    }

    mapping(IUniswapV2Pair => PairInfo) public pairs; // Map of pairs and their info
    mapping(address => IUniswapV2Pair) public callerInfo; // Map of callers to pairs

    function _get(IUniswapV2Pair pair, uint32 blockTimestamp) public view returns (uint256) {
        uint256 priceCumulative = pair.price1CumulativeLast();

        // if time has elapsed since the last update on the pair, mock the accumulated price values
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = IUniswapV2Pair(pair).getReserves();
        if (blockTimestampLast != blockTimestamp) {
            priceCumulative += uint256(FixedPoint.fraction(reserve1, reserve0)._x) * (blockTimestamp - blockTimestampLast); // overflows are desired
        }

        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        return priceCumulative;
    }

    function getDataParameter(IUniswapV2Pair pair) public pure returns (bytes memory) { return abi.encode(pair); }

    event Data(uint256 a, uint256 b, uint256 c);

    // Get the latest exchange rate, if no valid (recent) rate is available, return false
    function get(bytes calldata data) external override returns (bool, uint256) {
        IUniswapV2Pair pair = abi.decode(data, (IUniswapV2Pair));
        PairInfo memory pairInfo = pairs[pair];
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        if (pairInfo.blockTimestampLast == 0) {
            pairs[pair] = PairInfo(_get(pair, blockTimestamp), uint32(block.number), blockTimestamp);
            return (false, 0);
        }
        
        if (block.number.sub(pairInfo.blockHeightLast) < PERIOD) {
            return (false, 0);
        }

        uint256 priceCumulative = _get(pair, blockTimestamp);
        uint32 timeElapsed = blockTimestamp - pairInfo.blockTimestampLast; // substraction overflow is desired
        FixedPoint.uq112x112 memory priceAverage = FixedPoint.uq112x112(uint224((priceCumulative - pairInfo.priceCumulativeLast) / timeElapsed));
        pairs[pair] = PairInfo(priceCumulative, uint32(block.number), blockTimestamp);

        emit Data(priceCumulative, pairInfo.priceCumulativeLast, priceAverage.mul(10**18).decode144());
        return (true, priceAverage.mul(10**18).decode144());
    }

    // Check the last exchange rate without any state changes
    function peek(bytes calldata data) public override view returns (bool, uint256) {
        IUniswapV2Pair pair = abi.decode(data, (IUniswapV2Pair));
        PairInfo memory pairInfo = pairs[pair];
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        if (pairInfo.blockTimestampLast == 0 || blockTimestamp == pairInfo.blockTimestampLast) {
            return (false, 0);
        }
    
        bool available = true;
        if (block.number.sub(pairInfo.blockHeightLast) < PERIOD) {
            available = false;
        }

        uint256 priceCumulative = _get(pair, blockTimestamp);
        uint32 timeElapsed = blockTimestamp - pairInfo.blockTimestampLast; // overflow is desired
        FixedPoint.uq112x112 memory priceAverage = FixedPoint
            .uq112x112(uint224((priceCumulative - pairInfo.priceCumulativeLast) / timeElapsed));
        return (available, priceAverage.mul(10**18).decode144());
    }

    function name(bytes calldata) public override view returns (string memory) {
        return "SushiSwap TWAP";
    }

    function symbol(bytes calldata) public override view returns (string memory) {
        return "S";
    }
}
