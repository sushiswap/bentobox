// SPDX-License-Identifier: UNLICENSED

 // SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.12;

import "@boringcrypto/boring-solidity/contracts/interfaces/IMasterContract.sol";
import "../BentoBoxPlus.sol";

contract MaliciousMasterContractMock is IMasterContract{

	function init(bytes calldata data) external override payable {
		
	}

	function attack(BentoBoxPlus bentoBox) public {
		bentoBox.setMasterContractApproval(address(this), address(this), true, 0, 0, 0);
	}

}
