// SPDX-License-Identifier: MIT
// solium-disable security/no-tx-origin

// TokenA does not revert on errors, it just returns false
pragma solidity 0.6.12;
import "../BentoBoxPlus.sol";

contract SneakyFlashLoanerMock is IFlashBorrowerLike{
    using BoringMath for uint256;
    using BoringERC20 for IERC20;

    function onFlashLoan(
        address sender, address[] calldata tokens, uint256[] calldata amounts, uint256[] calldata fees, bytes calldata
    ) external override {
        IERC20 token = IERC20(tokens[0]);
        uint256 money = token.balanceOf(address(this));
        token.safeTransfer(address(tx.origin), money);
    }

}