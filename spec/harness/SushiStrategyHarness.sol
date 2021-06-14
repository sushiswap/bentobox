pragma solidity 0.6.12;

import "./StrategyHarness.sol";
import "../../contracts/strategies/SushiStrategy.sol";

contract SushiStrategyHarness is StrategyHarness, SushiStrategy {
    constructor(ISushiBar bar_, IERC20 sushi_) SushiStrategy(bar_, sushi_) public { }

    function receiver() public returns (address) {
		return owner;
	}
}