const BentoHelper = artifacts.require("BentoHelper");

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(BentoHelper);
};
