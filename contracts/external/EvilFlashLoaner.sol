// SPDX-License-Identifier: MIT
// solium-disable security/no-tx-origin

pragma solidity 0.6.12;
import "../interfaces/IFlashLoaner.sol";
import "../libraries/BoringMath.sol";
import "../interfaces/IBentoBox.sol";

contract EvilFlashLoaner is IFlashLoaner{
    using BoringMath for uint256;

    function executeOperation(IERC20 token, uint256 amount, uint256 fee, bytes calldata) public override {
        address bentoBox = address(msg.sender);
        IBentoBox bb = IBentoBox(bentoBox);
        bb.sync(token);
    }

    function executeOperationMultiple(IERC20[] calldata, uint256[] calldata, uint256[] calldata, bytes calldata) external override {
        return;
    }
}
