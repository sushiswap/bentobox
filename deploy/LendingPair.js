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
    lendingPair.setSwapper(sushiSwapSwapper.address, true)
  }
}

module.exports.dependencies = ["BentoBox", "SushiSwapSwapper", "Oracles"]
