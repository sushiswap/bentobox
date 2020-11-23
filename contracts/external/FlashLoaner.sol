// SPDX-License-Identifier: MIT
// TokenA does not revert on errors, it just returns false
pragma solidity ^0.6.12;
import "../interfaces/IERC20.sol";
import "../interfaces/IFlashLoaner.sol";
import "../libraries/BoringMath.sol";
import "../BentoBox.sol";


contract FlashLoaner is IFlashLoaner{
  using BoringMath for uint;

  function executeOperation(IERC20 token, uint256 amount, uint256 fee, bytes calldata params) public override {
    BentoBox bentoBox = BentoBox(msg.sender);
    uint payback = amount.add(fee);
    (bool success, bytes memory data) = address(bentoBox).delegatecall(params);
    require(success, "FlashLoaner: Delegate Call failed");
    //uint share = bentoBox.shareOf(token, address(this));
    //bentoBox.withdrawShare(token, address(this), share);
    //uint money = token.balanceOf(address(this));
    //uint winnings = money.sub(payback);
    //token.approve(address(bentoBox), payback);
    //token.transfer(tx.origin, winnings);
  }
}
