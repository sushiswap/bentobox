module.exports = async function ({ deployments, getNamedAccounts }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  await deploy("BentoHelper", {
    from: deployer,
    log: true,
    deterministicDeployment: true,
  })
}
