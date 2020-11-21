const Vault = artifacts.require("Vault");
const Pair = artifacts.require("Pair");
const BentoFactory = artifacts.require("BentoFactory");
const SushiSwapDelegateSwapper = artifacts.require("SushiSwapDelegateSwapper");

function e18(amount) {
  return new web3.utils.BN(amount).mul(new web3.utils.BN("1000000000000000000"));
}

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(Vault);
  await deployer.deploy(Pair);

  // Get the contracts
  let vault = await Vault.deployed();
  let pairMaster = await Pair.deployed();
  await deployer.deploy(BentoFactory, vault.address, pairMaster.address);
  let bentoFactory = await BentoFactory.deployed();
};
