const TokenA = artifacts.require("TokenA");
const TokenB = artifacts.require("TokenB");
const SushiSwapFactory = artifacts.require("UniswapV2Factory");

const Vault = artifacts.require("Vault");
const Pair = artifacts.require("Pair");
const PeggedOracle = artifacts.require("PeggedOracle");

module.exports = async function (deployer, network, accounts) {
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

  // Get the contracts
  let vault = await Vault.deployed();
  let pairMaster = await Pair.deployed();
  let oracle = await PeggedOracle.deployed();

  // Deploy new pair
  await vault.setPairContract(pairMaster.address, true);
  let tx = await vault.deploy(pairMaster.address, a.address, b.address, oracle.address);
  let raw_logs = await web3.eth.getPastLogs({
    fromBlock: 1,
    address: vault.address,
    topics: ['0xbb3432dd011e3a520780a665a087a29ccda830ea796ec3d85f051c7340a59c7f']
  });

  let pair_address = tx.logs[0].args[4];
  await oracle.set(pair_address, "1000000000000000000");
};
