// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../ERC20.sol";

contract TestERC20 is ERC20 {
<<<<<<< HEAD
  uint256 public totalSupply;
    constructor(
      uint256 _initialAmount
  ) public {
      balanceOf[msg.sender] = _initialAmount;               // Give the creator all initial tokens
      totalSupply = _initialAmount;                        // Update total supply
  }
=======
    uint256 public totalSupply;

    constructor(uint256 _initialAmount) public {
        // Give the creator all initial tokens
        balanceOf[msg.sender] = _initialAmount;
        // Update total supply
        totalSupply = _initialAmount;
    }
>>>>>>> 1759b0c (SAVEPOINT)
}
