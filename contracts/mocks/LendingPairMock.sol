// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../interfaces/IBentoBox.sol";
import "../LendingPair.sol";

contract LendingPairMock is LendingPair {
	constructor(IBentoBox bentoBox) public LendingPair(bentoBox) {}

	function setInterestPerBlock(uint64 interestPerBlock) public {
		accrueInfo.interestPerBlock = interestPerBlock;
	}
}
