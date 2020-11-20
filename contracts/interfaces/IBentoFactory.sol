// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import './IOracle.sol';
import './IPair.sol';

interface IBentoFactory {
    function createPair(IERC20 collateral, IERC20 asset, IOracle oracle_address, bytes calldata oracleData) external;
    function setMasterContract(IPair master_contract) external;
}