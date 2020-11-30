const PeggedOracle = artifacts.require("PeggedOracle");
const CompoundOracle = artifacts.require("CompoundOracle");
const ChainLinkOracle = artifacts.require("ChainLinkOracle");
const SimpleSLPTWAP0Oracle = artifacts.require("SimpleSLPTWAP0Oracle");
const SimpleSLPTWAP1Oracle = artifacts.require("SimpleSLPTWAP1Oracle");
const CompositeOracle = artifacts.require("CompositeOracle");

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(PeggedOracle);
  await deployer.deploy(CompoundOracle);
  await deployer.deploy(ChainLinkOracle);
  await deployer.deploy(SimpleSLPTWAP0Oracle);
  await deployer.deploy(SimpleSLPTWAP1Oracle);
  await deployer.deploy(CompositeOracle);
};
