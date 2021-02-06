// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "../BentoBox.sol";
import "../LendingPair.sol";

contract LendingPairMock is LendingPair {
    constructor(BentoBox bentoBox) public LendingPair(bentoBox) {
        return;
    }

    function accrueTwice() public {
        accrue();
        accrue();
    }

    function setInterestPerBlock(uint64 interestPerBlock) public {
        accrueInfo.interestPerBlock = interestPerBlock;
    }
}
