// SPDX-License-Identifier: MIT

import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

interface ISafeStrategy {
    function safeHarvest(
        uint256 maxBalance,
        bool rebalance,
        uint256 maxChangeAmount,
        bool harvestRewards
    ) external;

    function swapExactTokensForUnderlying(uint256 amountOutMin, address inputToken) external;
}

contract CombineHarvester is BoringOwnable {
    function sellRewardTokens(
        ISafeStrategy[] memory strategies,
        uint256[] memory minOutAmounts,
        address[] memory inputTokens
    ) external onlyOwner {
        for (uint256 i = 0; i < strategies.length; i++) {
            strategies[i].swapExactTokensForUnderlying(minOutAmounts[i], inputTokens[i]);
        }
    }

    function executeSafeHarvests(
        ISafeStrategy[] memory strategies,
        uint256[] memory maxBalances,
        bool[] memory rebalance,
        uint256[] memory maxChangeAmounts,
        bool[] memory harvestRewards
    ) external onlyOwner {
        for (uint256 i = 0; i < strategies.length; i++) {
            strategies[i].safeHarvest(maxBalances[i], rebalance[i], maxChangeAmounts[i], harvestRewards[i]);
        }
    }
}
