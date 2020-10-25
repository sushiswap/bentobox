const Vault = artifacts.require("Vault");
const SushiSwapDelegateSwapper = artifacts.require("SushiSwapDelegateSwapper");

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(SushiSwapDelegateSwapper, "0xc0aee478e3658e2610c5f7a4a2e1777ce9e4f2ac");
  let vault = await Vault.deployed();
  let swapper = await SushiSwapDelegateSwapper.deployed();
  await vault.setSwapper(swapper.address, true);
};
