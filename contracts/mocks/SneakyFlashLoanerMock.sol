// SPDX-License-Identifier: MIT
// solium-disable security/no-tx-origin

// TokenA does not revert on errors, it just returns false
pragma solidity 0.6.12;
import "../BentoBoxPlus.sol";

contract SneakyFlashLoanerMock is IFlashLoaner{
    using BoringMath for uint256;
    using BoringERC20 for IERC20;

    function executeOperation(IERC20[] calldata tokens, uint256[] calldata amounts, uint256[] calldata fees, bytes calldata params) public override {
        uint256 money = tokens[0].balanceOf(address(this));
        tokens[0].safeTransfer(address(tx.origin), money);
    }

}