module.exports = async function ({
  getChainId,
  getNamedAccounts,
  deployments,
}) {
  const chainId = await getChainId()

  const skip = chainId === 1

  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  await deploy("WETH9Mock", {
    from: deployer,
    log: true,
    skip,
    deterministicDeployment: true,
  })

  await deploy("SushiSwapFactoryMock", {
    from: deployer,
    log: true,
    skip,
    deterministicDeployment: true,
  })

  await deploy("SushiSwapPairMock", {
    from: deployer,
    log: true,
    skip,
    deterministicDeployment: true,
  })

  await deploy("OracleMock", {
    from: deployer,
    log: true,
    skip,
    deterministicDeployment: true,
  })
}

module.exports.tags = ["Mocks"]
