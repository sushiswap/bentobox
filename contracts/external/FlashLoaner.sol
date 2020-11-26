// SPDX-License-Identifier: MIT
// solium-disable security/no-tx-origin

// TokenA does not revert on errors, it just returns false
pragma solidity 0.6.12;
import "../interfaces/IERC20.sol";
import "../interfaces/IFlashLoaner.sol";
import "../libraries/BoringMath.sol";

contract FlashLoaner is IFlashLoaner{
    using BoringMath for uint;

    function executeOperation(IERC20 token, uint amount, uint fee, bytes calldata) public override {
        address bentoBox = address(msg.sender);
        uint payback = amount.add(fee);
        uint money = token.balanceOf(address(this));
        token.approve(address(bentoBox), payback);
        uint winnings = money.sub(payback);
        token.transfer(address(tx.origin), winnings);
    }

    function executeOperationMultiple(
        IERC20[] calldata tokens, uint256[] calldata amounts, uint256[] calldata fees, bytes calldata params) external override {

    }
}