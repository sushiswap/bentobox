module.exports = async function ({ ethers, getNamedAccounts, deployments }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const sushiSwapSwapper = await deployments.get("SushiSwapSwapper")

  const bentoBox = await deployments.get("BentoBox")

  const response = await deploy("LendingPair", {
    from: deployer,
    args: [bentoBox.address],
    log: true,
    // TODO: Had to disable this for the account to match, investigate...
    deterministicDeployment: false,
  })

  if (response.newlyDeployed) {
    const lendingPair = await ethers.getContract("LendingPair")

    // console.log("lending pair deployer", deployer)
    // console.log("lending pair owner", await lendingPair.owner())

    const peggedOracle = await ethers.getContract("PeggedOracle")

    lendingPair.setSwapper(sushiSwapSwapper.address, true)

    const oracleData = peggedOracle.getDataParameter("0")

    const initData = await lendingPair.getInitData(
      "0x0000000000000000000000000000000000000000",
      "0x0000000000000000000000000000000000000000",
      peggedOracle.address,
      oracleData
    )
    console.log("Initilising lendingPair...")
    lendingPair.init(initData)
    console.log("lendingPair initilised...")
  }
}

module.exports.dependencies = ["BentoBox", "SushiSwapSwapper", "Oracles"]
