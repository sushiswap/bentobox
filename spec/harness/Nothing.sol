pragma solidity 0.6.12;

interface Nothing { 
    function nop(bytes calldata data) external payable returns (bool, bytes memory);
}