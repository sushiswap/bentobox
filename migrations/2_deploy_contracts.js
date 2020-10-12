const TokenA = artifacts.require("TokenA");
const TokenB = artifacts.require("TokenB");
const SushiSwapFactory = artifacts.require("UniswapV2Factory");
const UniswapV2Pair = artifacts.require("UniswapV2Pair");

const Vault = artifacts.require("Vault");
const Pair = artifacts.require("Pair");
const PeggedOracle = artifacts.require("PeggedOracle");
const TestOracle = artifacts.require("TestOracle");
const SushiSwapDelegateSwapper = artifacts.require("SushiSwapDelegateSwapper");

function e18(amount) {
  return new web3.utils.BN(amount).mul(new web3.utils.BN("1000000000000000000"));
}

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(TokenA);
  await deployer.deploy(TokenB);
  await deployer.deploy(SushiSwapFactory, network == "ropsten" ? "0x9e6e344f94305d36eA59912b0911fE2c9149Ed3E" : accounts[0]);

  let a = await TokenA.deployed();
  let b = await TokenB.deployed();
  let factory = await SushiSwapFactory.deployed();
  let tx = await factory.createPair(a.address, b.address);
  let sushiswappair = await UniswapV2Pair.at(tx.logs[0].args.pair);
  a.transfer(sushiswappair.address, e18("5000"));
  b.transfer(sushiswappair.address, e18("5000"));
  await sushiswappair.mint(network == "ropsten" ? "0x9e6e344f94305d36eA59912b0911fE2c9149Ed3E" : accounts[0]);

  await deployer.deploy(Vault);
  await deployer.deploy(Pair);
  await deployer.deploy(PeggedOracle);
  await deployer.deploy(TestOracle);
  await deployer.deploy(SushiSwapDelegateSwapper, factory.address);

  // Get the contracts
  let vault = await Vault.deployed();
  let pairMaster = await Pair.deployed();
  let pegged_oracle = await PeggedOracle.deployed();
  let test_oracle = await TestOracle.deployed();
  let swapper = await SushiSwapDelegateSwapper.deployed();

  // Deploy new pair
  await vault.setPairContract(pairMaster.address, true);
  await vault.setSwapper(swapper.address, true);
  tx = await vault.deploy(pairMaster.address, a.address, b.address, test_oracle.address);
  let pair_address = tx.logs[0].args[4];
  await pegged_oracle.set(pair_address, "1000000000000000000");
  await test_oracle.set(pair_address, "1000000000000000000");
};
