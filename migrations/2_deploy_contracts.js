const BentoBox = artifacts.require("BentoBox");
const Pair = artifacts.require("LendingPair");
const WETH9 = artifacts.require("WETH9");
const {e18} = require("../test/helpers/utils");

const DEFAULT_WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
                     

module.exports = async function (deployer, network, accounts) {
  let wethAddress;
  if (process.env.NOT_TESTNET) {
    wethAddress = DEFAULT_WETH;
  } else {
    await deployer.deploy(WETH9);
    let weth = await WETH9.deployed();
    wethAddress = weth.address;
  }
  await deployer.deploy(BentoBox, wethAddress);
  let bentoBox = await BentoBox.deployed();
  await deployer.deploy(Pair, bentoBox.address);

  // Get the contracts
  let pairMaster = await Pair.deployed();
  let initData = await pairMaster.getInitData("0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000", "0x0");
  pairMaster.init(initData);
};
