module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  await deploy("WETH9Mock", {
    from: deployer,
    log: true,
    deterministicDeployment: true,
  })

  await deploy("SushiSwapFactoryMock", {
    from: deployer,
    log: true,
    deterministicDeployment: true,
  })

  await deploy("SushiSwapPairMock", {
    from: deployer,
    log: true,
    deterministicDeployment: true,
  })

  await deploy("OracleMock", {
    from: deployer,
    log: true,
    deterministicDeployment: true,
  })
}

module.exports.skip = ({ getChainId }) =>
  new Promise(async (resolve, reject) => {
    try {
      const chainId = await getChainId()
      resolve(chainId !== "31337")
    } catch (error) {
      reject(error)
    }
  })

module.exports.tags = ["Mocks"]
