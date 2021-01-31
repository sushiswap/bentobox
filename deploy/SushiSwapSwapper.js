const DEFAULT_SUSHISWAP_FACTORY = "0xc0aee478e3658e2610c5f7a4a2e1777ce9e4f2ac"
const ROPSTEN_SUSHISWAP_FACTORY = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"

const FACTORY_MAP = new Map()
FACTORY_MAP.set(1, DEFAULT_SUSHISWAP_FACTORY)
FACTORY_MAP.set(3, ROPSTEN_SUSHISWAP_FACTORY)

module.exports = async function ({ deployments, getChainId, getNamedAccounts }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const chainId = await getChainId()

  const bentoBox = await deployments.get("BentoBoxPlus")

  const factoryAddress = FACTORY_MAP.has(chainId) ? FACTORY_MAP.get(chainId) : (await deployments.get("SushiSwapFactoryMock")).address

  await deploy("SushiSwapSwapper", {
    from: deployer,
    args: [bentoBox.address, factoryAddress],
    log: true,
    deterministicDeployment: true,
  })
}

module.exports.dependencies = ["Mocks", "BentoBox"]

module.exports.tags = ["SushiSwapSwapper"]
