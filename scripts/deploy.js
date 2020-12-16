const DEFAULT_WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"

const WETH_MAP = new Map()
WETH_MAP.set(1, DEFAULT_WETH)

// scripts/deploy.js
async function main() {
  // ...

  let wethAddress

  if (WETH_MAP.has(ethers.provider._network.chainId)) {
    console.log("Using WETH from WETH_MAP")
    wethAddress = WETH_MAP.get(ethers.provider._network.chainId)
  } else {
    const WETH9 = await ethers.getContractFactory("WETH9Mock")
    console.log("Deploying WETH9...")
    const weth9 = await WETH9.deploy()
    await weth9.deployed()
    wethAddress = weth9.address
    console.log("WETH9 deployed to:", weth9.address)
  }

  // ...
  const BentoBox = await ethers.getContractFactory("BentoBox")
  console.log("Deploying BentoBox...")
  const bentoBox = await BentoBox.deploy(wethAddress)
  await bentoBox.deployed()
  console.log("BentoBox deployed to:", bentoBox.address)

  // ...
  const LendingPair = await ethers.getContractFactory("LendingPair")
  console.log("Deploying LendingPair...")
  const lendingPair = await LendingPair.deploy(bentoBox.address)
  await lendingPair.deployed()
  console.log("LendingPair deployed to:", lendingPair.address)

  // ...
  // lendingPair.setBentoBox(bentoBox.address, lendingPair.address);

  // ...
  const SushiSwapSwapper = await ethers.getContractFactory("SushiSwapSwapper")
  console.log("Deploying SushiSwapSwapper...")
  const sushiSwapSwapper = await SushiSwapSwapper.deploy(
    bentoBox.address,
    "0xc0aee478e3658e2610c5f7a4a2e1777ce9e4f2ac"
  )
  await sushiSwapSwapper.deployed()
  console.log("SushiSwapSwapper deployed to:", sushiSwapSwapper.address)

  // ...
  lendingPair.setSwapper(sushiSwapSwapper.address, true)

  // ...
  const PeggedOracle = await ethers.getContractFactory("PeggedOracle")
  console.log("Deploying PeggedOracle...")
  const peggedOracle = await PeggedOracle.deploy()
  await peggedOracle.deployed()
  console.log("PeggedOracle deployed to:", peggedOracle.address)

  // ...

  const data = await peggedOracle.getDataParameter("0")

  let initData = await lendingPair.getInitData(
    "0x0000000000000000000000000000000000000000",
    "0x0000000000000000000000000000000000000000",
    peggedOracle.address,
    data
  )
  console.log("Initilising lendingPair...")
  lendingPair.init(initData)
  console.log("lendingPair initilised...")

  // ...
  const CompoundOracle = await ethers.getContractFactory("CompoundOracle")
  console.log("Deploying CompoundOracle...")
  const compoundOracle = await CompoundOracle.deploy()
  await compoundOracle.deployed()
  console.log("CompoundOracle deployed to:", compoundOracle.address)

  // ...
  const ChainlinkOracle = await ethers.getContractFactory("ChainlinkOracle")
  console.log("Deploying ChainlinkOracle...")
  const chainlinkOracle = await ChainlinkOracle.deploy()
  await chainlinkOracle.deployed()
  console.log("ChainlinkOracle deployed to:", chainlinkOracle.address)

  // ...
  const SimpleSLPTWAP0Oracle = await ethers.getContractFactory(
    "SimpleSLPTWAP0Oracle"
  )
  console.log("Deploying simpleSLPTWAP0Oracle...")
  const simpleSLPTWAP0Oracle = await SimpleSLPTWAP0Oracle.deploy()
  await simpleSLPTWAP0Oracle.deployed()
  console.log("SimpleSLPTWAP0Oracle deployed to:", simpleSLPTWAP0Oracle.address)

  // ...
  const SimpleSLPTWAP1Oracle = await ethers.getContractFactory(
    "SimpleSLPTWAP1Oracle"
  )
  console.log("Deploying SimpleSLPTWAP1Oracle...")
  const simpleSLPTWAP1Oracle = await SimpleSLPTWAP1Oracle.deploy()
  await simpleSLPTWAP1Oracle.deployed()
  console.log("SimpleSLPTWAP1Oracle deployed to:", simpleSLPTWAP1Oracle.address)

  // ...
  const CompositeOracle = await ethers.getContractFactory("CompositeOracle")
  console.log("Deploying CompositeOracle...")
  const compositeOracle = await CompositeOracle.deploy()
  await compositeOracle.deployed()
  console.log("CompositeOracle deployed to:", compositeOracle.address)

  // ...
  const BentoHelper = await ethers.getContractFactory("BentoHelper")
  console.log("Deploying BentoHelper...")
  const bentoHelper = await BentoHelper.deploy()
  await bentoHelper.deployed()
  console.log("BentoHelper deployed to:", bentoHelper.address)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
