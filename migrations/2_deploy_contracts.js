const BentoBox = artifacts.require("BentoBox");
const Pair = artifacts.require("LendingPair");
const SushiSwapDelegateSwapper = artifacts.require("SushiSwapDelegateSwapper");

function e18(amount) {
  return new web3.utils.BN(amount).mul(new web3.utils.BN("1000000000000000000"));
}

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(BentoBox);
  await deployer.deploy(Pair);

  // Get the contracts
  let bentoBox = await BentoBox.deployed();
  let pairMaster = await Pair.deployed();
  pairMaster.setBentoBox(bentoBox.address, pairMaster.address);
};
