module.exports = async function ({ ethers, getNamedAccounts, deployments }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const sushiSwapSwapper = await deployments.get("SushiSwapSwapper")

  const bentoBox = await deployments.get("BentoBoxPlus")

  const chainId = await getChainId()

  const lendingPairContract = chainId !== 31337 ? "LendingPair" : "LendingPairMock"

  const response = await deploy(lendingPairContract, {
    from: deployer,
    args: [bentoBox.address],
    log: true,
    // TODO: Had to disable this for the account to match, investigate...
    deterministicDeployment: false,
  })

  if (response.newlyDeployed) {
    const lendingPair = await ethers.getContract(lendingPairContract)

    lendingPair.setSwapper(sushiSwapSwapper.address, true)
  }
}

module.exports.dependencies = ["BentoBox", "SushiSwapSwapper", "Oracles"]
