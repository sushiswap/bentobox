// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IMasterContract {
    function setBentoBox(address bentoBox_, address masterContract_) external;
}