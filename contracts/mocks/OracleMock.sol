// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.12;
import "../libraries/BoringMath.sol";
import "../interfaces/IOracle.sol";

// WARNING: This oracle is only for testing, please use PeggedOracle for a fixed value oracle
contract OracleMock is IOracle {
	using BoringMath for uint256;

	uint256 rate;

	function set(uint256 rate_, address) public {
		// The rate can be updated.
		rate = rate_;
	}

	function getDataParameter() public pure returns (bytes memory) {
		return abi.encode("0x0");
	}

	// Get the latest exchange rate
	function get(bytes calldata) public override returns (bool, uint256) {
		return (true, rate);
	}

	// Check the last exchange rate without any state changes
	function peek(bytes calldata) public view override returns (bool, uint256) {
		return (true, rate);
	}

	function name(bytes calldata) public view override returns (string memory) {
		return "Test";
	}

	function symbol(bytes calldata) public view override returns (string memory) {
		return "TEST";
	}
}
