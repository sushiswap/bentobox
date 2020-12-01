#!/bin/sh
rm -R flat
mkdir flat
truffle-flattener contracts/BentoBox.sol > flat/BentoBox.sol
truffle-flattener contracts/LendingPair.sol > flat/LendingPair.sol
truffle-flattener contracts/swappers/SushiSwapSwapper.sol > flat/SushiSwapSwapper.sol
truffle-flattener contracts/oracles/PeggedOracle.sol > flat/PeggedOracle.sol
truffle-flattener contracts/oracles/CompoundOracle.sol > flat/CompoundOracle.sol
truffle-flattener contracts/oracles/ChainLinkOracle.sol > flat/ChainLinkOracle.sol
truffle-flattener contracts/oracles/SimpleSLPTWAP0Oracle.sol > flat/SimpleSLPTWAP0Oracle.sol
truffle-flattener contracts/oracles/SimpleSLPTWAP1Oracle.sol > flat/SimpleSLPTWAP1Oracle.sol
truffle-flattener contracts/oracles/CompositeOracle.sol > flat/CompositeOracle.sol
truffle-flattener contracts/BentoHelper.sol > flat/BentoHelper.sol 
