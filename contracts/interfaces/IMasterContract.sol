// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IMasterContract {
    function init(address bentoBox_, address masterContract_, bytes calldata data) external;
}