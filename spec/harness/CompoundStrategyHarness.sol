pragma solidity 0.6.12;

import "./StrategyHarness.sol";
import "../../contracts/strategies/CompoundStrategy.sol";

contract CompoundStrategyHarness is StrategyHarness, CompoundStrategy {
    constructor(address bentobox_, IFactory factory_, IERC20 token_, IcToken cToken_,
                IERC20 compToken_, IERC20 weth_) CompoundStrategy(bentobox_, factory_, token_, cToken_, compToken_, weth_) public { }

    function receiver() public returns (address) {
		return bentobox;
	}

	function tokenBalanceOf(address token, 
			address account) public returns (uint256)  {
				return (IERC20(token)).balanceOf(account);
	}
}