import { BentoBoxV1 } from '../types'
import { task } from 'hardhat/config'

task('transfer-ownership', 'Transfer ownership of BentoBox')
  .addParam('address', 'Owner address')
  .setAction(async function ({ address }: { address: string }, { ethers }) {
    const bentoBox = await ethers.getContract<BentoBoxV1>('BentoBoxV1')
    await bentoBox.transferOwnership(address, true, false)
  })
