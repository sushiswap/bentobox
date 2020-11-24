const BentoBox = artifacts.require("BentoBox");
const Pair = artifacts.require("LendingPair");
const SushiSwapDelegateSwapper = artifacts.require("SushiSwapDelegateSwapper");
const {e18} = require("../test/helpers/utils");


module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(BentoBox, "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2");
  await deployer.deploy(Pair);

  // Get the contracts
  let bentoBox = await BentoBox.deployed();
  let pairMaster = await Pair.deployed();
  pairMaster.setBentoBox(bentoBox.address, pairMaster.address);
};
