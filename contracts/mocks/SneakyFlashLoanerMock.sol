// SPDX-License-Identifier: MIT
// solium-disable security/no-tx-origin

// TokenA does not revert on errors, it just returns false
pragma solidity 0.6.12;
import "../interfaces/IERC3156FlashLoan.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";

contract SneakyFlashLoanerMock is IERC3156BatchFlashBorrower{
    using BoringMath for uint256;
    using BoringERC20 for IERC20;

    function onBatchFlashLoan(
        address sender,
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata fees,
        bytes calldata data
    ) external override {
        IERC20 token = tokens[0];
        uint256 money = token.balanceOf(address(this));
        token.safeTransfer(address(tx.origin), money);
    }

}