const DEFAULT_WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

// scripts/deploy.js
async function main() {
  // ...
  const WETH9 = await ethers.getContractFactory("WETH9");
  console.log("Deploying WETH9...");
  const weth9 = await WETH9.deploy();
  await weth9.deployed();
  console.log("WETH9 deployed to:", weth9.address);

  // ...
  const BentoBox = await ethers.getContractFactory("BentoBox");
  console.log("Deploying BentoBox...");
  const bentoBox = await BentoBox.deploy(weth9.address);
  await bentoBox.deployed();
  console.log("BentoBox deployed to:", bentoBox.address);

  // ...
  const LendingPair = await ethers.getContractFactory("LendingPair");
  console.log("Deploying LendingPair...");
  const lendingPair = await LendingPair.deploy(bentoBox.address);
  await lendingPair.deployed();
  console.log("LendingPair deployed to:", lendingPair.address);

  // ...
  // lendingPair.setBentoBox(bentoBox.address, lendingPair.address);

  // ...
  const SushiSwapSwapper = await ethers.getContractFactory("SushiSwapSwapper");
  console.log("Deploying SushiSwapSwapper...");
  const sushiSwapSwapper = await SushiSwapSwapper.deploy(
    bentoBox.address,
    "0xc0aee478e3658e2610c5f7a4a2e1777ce9e4f2ac"
  );
  await sushiSwapSwapper.deployed();
  console.log("SushiSwapSwapper deployed to:", sushiSwapSwapper.address);

  // ...
  lendingPair.setSwapper(sushiSwapSwapper.address, true);

  // ...
  const PeggedOracle = await ethers.getContractFactory("PeggedOracle");
  console.log("Deploying PeggedOracle...");
  const peggedOracle = await PeggedOracle.deploy();
  await peggedOracle.deployed();
  console.log("PeggedOracle deployed to:", peggedOracle.address);

  // ...

  const data = await peggedOracle.getDataParameter("0");

  let initData = await lendingPair.getInitData(
    "0x0000000000000000000000000000000000000000",
    "0x0000000000000000000000000000000000000000",
    peggedOracle.address,
    data
  );
  console.log("Initilising lendingPair...");
  lendingPair.init(initData);
  console.log("lendingPair initilised...");

  // ...
  const CompoundOracle = await ethers.getContractFactory("CompoundOracle");
  console.log("Deploying CompoundOracle...");
  const compoundOracle = await CompoundOracle.deploy();
  await compoundOracle.deployed();
  console.log("CompoundOracle deployed to:", compoundOracle.address);

  // ...
  const BentoHelper = await ethers.getContractFactory("BentoHelper");
  console.log("Deploying BentoHelper...");
  const bentoHelper = await BentoHelper.deploy();
  await bentoHelper.deployed();
  console.log("BentoHelper deployed to:", bentoHelper.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
