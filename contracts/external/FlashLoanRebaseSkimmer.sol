// SPDX-License-Identifier: MIT
// solium-disable security/no-tx-origin

// TokenA does not revert on errors, it just returns false
pragma solidity 0.6.12;
import "../interfaces/IFlashLoaner.sol";
import "../libraries/BoringMath.sol";
import {RebaseToken} from "./RebaseToken.sol";
import "../BentoBox.sol";

contract FlashLoanRebaseSkimmer is IFlashLoaner{
    using BoringMath for uint;

    function executeOperation(IERC20 token, uint amount, uint fee, bytes calldata) public override {
        address bentoBox = address(msg.sender);
        uint payback = amount.add(fee);


        // increase rebase
        uint256 supply = token.totalSupply();
        RebaseToken rt = RebaseToken(address(token));
        rt.rebase(int256(supply));
        // call skim
        BentoBox bb = BentoBox(bentoBox);
        bb.skim(token);
        // if this is called by the token, reentrancy is caught
        // bb.sync();
        // pay out 
        uint money = token.balanceOf(address(this));
        token.approve(address(bentoBox), payback);
        uint winnings = money.sub(payback);
        token.transfer(address(tx.origin), winnings);
    }

    function executeOperationMultiple(
        IERC20[] calldata tokens, uint256[] calldata amounts, uint256[] calldata fees, bytes calldata params) external override {

    }
}