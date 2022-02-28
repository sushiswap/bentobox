import { DeployFunction } from 'hardhat-deploy/types'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { WNATIVE_ADDRESS } from '@sushiswap/core-sdk'

const deployFunction: DeployFunction = async function ({
  deployments,
  getChainId,
  getNamedAccounts,
  ethers,
}: HardhatRuntimeEnvironment) {
  const { deploy } = deployments
  const chainId = parseInt(await getChainId())
  const { deployer } = await getNamedAccounts()

  const wrappedNativeAddress =
    chainId !== 31337
      ? WNATIVE_ADDRESS[chainId]
      : await ethers
          .getContractFactory('WETH9Mock')
          .then((contractFactory) => contractFactory.deploy())
          .then((contract) => contract.deployed())
          .then((contract) => contract.address)

  await deploy('BentoBoxV1', {
    from: deployer,
    args: [wrappedNativeAddress],
    log: true,
    deterministicDeployment: false,
  })
}

export default deployFunction

deployFunction.dependencies = []

deployFunction.tags = ['BentoBoxV1']
