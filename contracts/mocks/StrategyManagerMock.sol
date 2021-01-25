// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.12;

import "../StrategyManager.sol";

// SushiBar is the coolest bar in town. You come in with some Sushi, and leave with more! The longer you stay, the more Sushi you get.
//
// This contract handles swapping to and from xSushi, SushiSwap's staking token.
contract StrategyManagerMock is StrategyManager {
    event LogHarvest(address indexed token, int256 amount);

    // F1 - F10: OK
    // F5: Total amount is updated AFTER interaction. But strategy is under our control.
    // C1 - C23: OK
    function setStrategy(IERC20 token, IStrategy newStrategy) public {

        emit LogHarvest(address(token), _setStrategy(token, newStrategy));
    }

    // F1 - F10: OK
    // F5: Total amount is updated AFTER interaction. But strategy is under our control.
    // C1 - C23: OK
    // REENT: Can be used to increase (and maybe decrease) totals[token].amount
    function harvest(IERC20 token, bool balance) public {
        emit LogHarvest(address(token), strategy[token].harvest(0));
        if (balance) {
            _balanceStrategy(token); // REENT: Exit (only for attack on other tokens)
        }
    }

}