module.exports = async function ({
  deployments,
  getChainId,
  getNamedAccounts,
}) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const chainId = await getChainId()

  const wethAddress =
    chainId === 1 ? DEFAULT_WETH : (await deployments.get("WETH9Mock")).address

  await deploy("BentoBox", {
    from: deployer,
    args: [wethAddress],
    log: true,
    deterministicDeployment: true,
  })
}

module.exports.dependencies = ["Mocks"]
