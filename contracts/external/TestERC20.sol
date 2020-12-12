pragma solidity 0.6.12;

import "../ERC20.sol";

contract TestERC20 is ERC20 {
    uint256 public totalSupply;

    constructor(
      uint256 _initialAmount
  ) public {
      balanceOf[msg.sender] = _initialAmount;               // Give the creator all initial tokens
      totalSupply = _initialAmount;                        // Update total supply
  }
}
