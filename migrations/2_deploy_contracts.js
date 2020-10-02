const Vault = artifacts.require("Vault");
const TokenA = artifacts.require("TokenA");
const TokenB = artifacts.require("TokenB");
const Pair = artifacts.require("Pair");
const PeggedOracle = artifacts.require("PeggedOracle");

module.exports = async function (deployer) {
  await deployer.deploy(Vault);
  await deployer.deploy(TokenA);
  await deployer.deploy(TokenB);
  await deployer.deploy(Pair);
  await deployer.deploy(PeggedOracle);

  // Get the contracts
  let vault = await Vault.deployed();
  let a = await TokenA.deployed();
  let b = await TokenB.deployed();
  let pairMaster = await Pair.deployed();
  let oracle = await PeggedOracle.deployed();

  // Deploy new pair
  await vault.addPairContract(pairMaster.address);
  await vault.deploy(pairMaster.address, a.address, b.address, oracle.address);
  let pair_address = await vault.pairs(0);
  await oracle.set(pair_address, "1000000000000000000");
};
