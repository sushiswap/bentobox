// SPDX-License-Identifier: UNLICENSED
// solhint-disable avoid-low-level-calls

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./interfaces/IERC20.sol";

contract BoringBatchable {
    function permit(IERC20 token, address from, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        token.permit(from, address(this), amount, deadline, v, r, s);
    }

    function batch(bytes[] calldata calls, bool revertOnFail) external payable returns(bool[] memory successes, bytes[] memory results) {
        successes = new bool[](calls.length);
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);
            require(success || !revertOnFail, "BoringBatchable: Tx failed");
            successes[i] = success;
            results[i] = result;
        }
    }
}