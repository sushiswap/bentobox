const BentoBox = artifacts.require("BentoBox");
const Pair = artifacts.require("LendingPair");
const WETH9 = artifacts.require("WETH9");
const {e18} = require("../test/helpers/utils");

const DEFAULT_WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

module.exports = async function (deployer, network, accounts) {

  await deployer.deploy(WETH9);
  let weth = await WETH9.deployed();
  let wethAddress = weth.address;
  if (process.env.NOT_TESTNET) {
    wethAddress = DEFAULT_WETH;
  }
  await deployer.deploy(BentoBox, wethAddress);
  await deployer.deploy(Pair);

  // Get the contracts
  let bentoBox = await BentoBox.deployed();
  let pairMaster = await Pair.deployed();
  pairMaster.setBentoBox(bentoBox.address, pairMaster.address);
};
