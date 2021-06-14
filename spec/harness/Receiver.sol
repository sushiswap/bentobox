pragma solidity 0.6.12;

contract Receiver {

    fallback() external payable {}
    receive() external payable {}
}
