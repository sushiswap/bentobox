module.exports = async function ({ deployments, getNamedAccounts }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  await deploy("ChainlinkOracle", {
    from: deployer,
    log: true,
    deterministicDeployment: true,
  })

  await deploy("CompositeOracle", {
    from: deployer,
    log: true,
    deterministicDeployment: true,
  })

  await deploy("CompoundOracle", {
    from: deployer,
    log: true,
    deterministicDeployment: true,
  })

  await deploy("PeggedOracle", {
    from: deployer,
    log: true,
    deterministicDeployment: true,
  })

  await deploy("SimpleSLPTWAP0Oracle", {
    from: deployer,
    log: true,
    deterministicDeployment: true,
  })

  await deploy("SimpleSLPTWAP1Oracle", {
    from: deployer,
    log: true,
    deterministicDeployment: true,
  })
}

module.exports.tags = ["Oracles"]
