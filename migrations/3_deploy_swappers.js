const Pair = artifacts.require("LendingPair");
const BentoBox = artifacts.require("BentoBox");
const SushiSwapSwapper = artifacts.require("SushiSwapSwapper");

module.exports = async function (deployer, network, accounts) {
  let bentoBox = await BentoBox.deployed();
  await deployer.deploy(SushiSwapSwapper, bentoBox.address, "0xc0aee478e3658e2610c5f7a4a2e1777ce9e4f2ac");
  let pairMaster = await Pair.deployed();
  let swapper = await SushiSwapSwapper.deployed();
  // TODO: Make this work
  await pairMaster.setSwapper(swapper.address, true);
};
