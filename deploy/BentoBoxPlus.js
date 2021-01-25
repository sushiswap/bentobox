const DEFAULT_WETH = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
const ROPSTEN_WETH = "0xc778417E063141139Fce010982780140Aa0cD5Ab"

const WETH_MAP = new Map()
WETH_MAP.set(1, DEFAULT_WETH)
WETH_MAP.set(3, ROPSTEN_WETH)

module.exports = async function ({ deployments, getChainId, getNamedAccounts }) {
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts()

  const chainId = await getChainId()

  const wethAddress = WETH_MAP.has(chainId) ? WETH_MAP.get(chainId) : (await deployments.get("WETH9Mock")).address

  await deploy("BentoBoxPlus", {
    from: deployer,
    args: [wethAddress],
    log: true,
    deterministicDeployment: false,
  })
}

module.exports.dependencies = ["Mocks"]
