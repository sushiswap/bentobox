// SPDX-License-Identifier: MIT
// solium-disable security/no-tx-origin

// TokenA does not revert on errors, it just returns false
pragma solidity 0.6.12;
import "../BentoBoxPlus.sol";

contract FlashLoanerMock is IFlashLoaner{
    using BoringMath for uint256;
    using BoringERC20 for IERC20;

    function executeOperation(IERC20[] calldata tokens, uint256[] calldata amounts, uint256[] calldata fees, bytes calldata params) public override {
        address bentoBox = address(msg.sender);
        uint256 payback = amounts[0].add(fees[0]);
        uint256 money = tokens[0].balanceOf(address(this));
        tokens[0].safeTransfer(address(bentoBox), payback);
        uint256 winnings = money.sub(payback);
        tokens[0].safeTransfer(address(tx.origin), winnings);
    }

}