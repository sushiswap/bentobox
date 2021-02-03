// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../BentoBoxPlus.sol";

contract BentoBoxPlusMock is BentoBoxPlus {
    
    constructor(IERC20 weth) public BentoBoxPlus(weth) {}

    function addProfit(IERC20 token, uint256 amount) public {
        totals[token].addElastic(amount);
    }
    
}
