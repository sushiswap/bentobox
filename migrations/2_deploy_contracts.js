const TokenA = artifacts.require("TokenA");
const TokenB = artifacts.require("TokenB");
const SushiSwapFactory = artifacts.require("UniswapV2Factory");

const Vault = artifacts.require("Vault");
const Pair = artifacts.require("Pair");
const PeggedOracle = artifacts.require("PeggedOracle");
const TestOracle = artifacts.require("TestOracle");

module.exports = async function (deployer, network, accounts) {
  console.log("Network:", network);
  await deployer.deploy(TokenA);
  await deployer.deploy(TokenB);
  await deployer.deploy(SushiSwapFactory, accounts[0]);

  let a = await TokenA.deployed();
  let b = await TokenB.deployed();
  let factory = await SushiSwapFactory.deployed();
  await factory.createPair(a.address, b.address);

  await deployer.deploy(Vault);
  await deployer.deploy(Pair);
  await deployer.deploy(PeggedOracle);
  await deployer.deploy(TestOracle);

  // Get the contracts
  let vault = await Vault.deployed();
  let pairMaster = await Pair.deployed();
  let pegged_oracle = await PeggedOracle.deployed();
  let test_oracle = await TestOracle.deployed();

  // Deploy new pair
  await vault.setPairContract(pairMaster.address, true);
  let tx = await vault.deploy(pairMaster.address, a.address, b.address, test_oracle.address);
  let pair_address = tx.logs[0].args[4];
  await pegged_oracle.set(pair_address, "1000000000000000000");
  await test_oracle.set(pair_address, "1000000000000000000");
};
