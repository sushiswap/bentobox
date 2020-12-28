// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;
import "./BoringMath.sol";

struct Rebase {
    uint128 amount;
    uint128 share;
}

library RebaseLibrary {
    using BoringMath for uint256;

    function toShare(Rebase memory tt, uint256 a) internal pure returns (uint256 amount) {
        amount = tt.amount == 0 ? a : a.mul(tt.share) / tt.amount;
    }

    function toAmount(Rebase memory tt, uint256 s) internal pure returns (uint256 share) {
        share = tt.share == 0 ? s : s.mul(tt.amount) / tt.share;
    }
}