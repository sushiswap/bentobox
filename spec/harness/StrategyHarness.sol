pragma solidity 0.6.12;

import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";

contract StrategyHarness {
    using BoringMath for uint256;

	function compareLEzero(int256 x) external returns (bool) {
		return x <= 0;
	}

	function compareLTzero(int256 x) external returns (bool) {
		return x < 0;
	}

	function compareGEzero(int256 x) external returns (bool) {
		return x >= 0;
	}

	function compareGTzero(int256 x) external returns (bool) {
		return x > 0;
	}

	function compareLEmaxUint255(int256 x) external returns (bool) {
		return x < (2^255 -1);
	}

	function checkAplusBeqC(uint256 a, int256 b, uint256 c) public returns (bool) {
		if (b >= 0) {
            uint256 b_ = uint256(b);
            return a.add(b_) == c;
        } else if (b < 0) {
            uint256 b_ = uint256(-b);
            return a.sub(b_) == c;
        }
	}

	function subToInt(uint256 a, uint256 b) public returns (int256) {
		return int256(a - b);
	}

	function safeSub(uint256 a, uint256 b) public returns (int256) {
		int256 c = int256(a - b);
		require((a > b && c > 0) || ( a <= b && c <= 0), "underflow");
		return c;
	}
}