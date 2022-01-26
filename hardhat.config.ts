import 'dotenv/config'
import '@nomiclabs/hardhat-etherscan'
import '@nomiclabs/hardhat-solhint'
import '@nomiclabs/hardhat-waffle'
import '@nomiclabs/hardhat-ethers'
import '@tenderly/hardhat-tenderly'
import '@typechain/hardhat'
import 'hardhat-contract-sizer'
import 'hardhat-deploy'
import 'hardhat-docgen'
import 'hardhat-gas-reporter'
import 'hardhat-spdx-license-identifier'
import 'hardhat-tracer'
import 'hardhat-watcher'
import 'solidity-coverage'

import { HardhatUserConfig } from 'hardhat/config'
import { removeConsoleLog } from 'hardhat-preprocessor'

const accounts = {
  mnemonic: process.env.MNEMONIC || 'test test test test test test test test test test test junk',
  accountsBalance: '990000000000000000000',
}

const config: HardhatUserConfig = {
  docgen: {
    path: './documentation',
    clear: false,
    runOnCompile: false,
  },
  defaultNetwork: 'hardhat',
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  gasReporter: {
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    currency: 'USD',
    enabled: process.env.REPORT_GAS === 'true',
    excludeContracts: [
      'contracts/flat/',
      'contracts/interfaces/',
      'contracts/libraries/',
      'contracts/mocks/',
      'contracts/samples/',
    ],
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    dev: {
      default: 1,
    },
    alice: {
      default: 2,
    },
    bob: {
      default: 3,
    },
    carol: {
      default: 4,
    },
    dave: {
      default: 5,
    },
    eve: {
      default: 6,
    },
    feeTo: {
      default: 7,
    },
  },
  networks: {
    localhost: {
      live: false,
      saveDeployments: true,
      tags: ['local'],
    },
    hardhat: {
      blockGasLimit: 10000000,
      chainId: 31337,
      accounts,
      live: false,
      saveDeployments: true,
      tags: ['test', 'local'],
      // Solidity-coverage overrides gasPrice to 1 which is not compatible with EIP1559
      hardfork: process.env.CODE_COVERAGE ? 'berlin' : 'london',
      forking: {
        enabled: process.env.FORKING === 'true',
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
        blockNumber: 11829739,
      },
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts,
      chainId: 1,
      forking: {
        enabled: process.env.FORKING === 'true',
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
        blockNumber: 11829739,
      },
    },
    ropsten: {
      url: `https://ropsten.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts,
      chainId: 3,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts,
      chainId: 4,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts,
      chainId: 5,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
    },
    kovan: {
      url: `https://kovan.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts,
      chainId: 42,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
    },
    moonbase: {
      url: 'https://rpc.testnet.moonbeam.network',
      accounts,
      chainId: 1287,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
    },
    arbitrum: {
      url: 'https://kovan3.arbitrum.io/rpc',
      accounts,
      chainId: 79377087078960,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
    },
    binance: {
      url: 'https://bsc-dataseed.binance.org/',
      accounts,
      chainId: 56,
      live: true,
      saveDeployments: true,
    },
    binancetest: {
      url: 'https://data-seed-prebsc-1-s1.binance.org:8545/',
      accounts,
      chainId: 97,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
    },
    matic: {
      url: 'https://rpc-mainnet.maticvigil.com/',
      accounts,
      chainId: 137,
      live: true,
      saveDeployments: true,
    },
    fantom: {
      url: 'https://rpcapi.fantom.network',
      accounts,
      chainId: 250,
      live: true,
      saveDeployments: true,
    },
    fantomtest: {
      url: 'https://rpc.testnet.fantom.network/',
      accounts,
      chainId: 4002,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
    },
    avalanche: {
      url: 'https://ava.spacejelly.network/api/ext/bc/C/rpc',
      accounts,
      chainId: 43114,
      live: true,
      saveDeployments: true,
    },
    fuji: {
      url: 'https://api.avax-test.network/ext/bc/C/rpc',
      accounts,
      chainId: 43113,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
    },
    mumbai: {
      url: 'https://rpc-mumbai.maticvigil.com/',
      accounts,
      chainId: 80001,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
    },
    huobi: {
      url: 'https://http-mainnet.hecochain.com',
      accounts,
      chainId: 128,
      live: true,
      saveDeployments: true,
    },
    huobitest: {
      url: 'https://http-testnet.hecochain.com',
      accounts,
      chainId: 256,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
    },
    okex: {
      url: 'http://okexchain-rpc1.okex.com:26659',
      accounts,
      chainId: 66,
      live: true,
      saveDeployments: true,
    },
    okextest: {
      url: 'http://okexchaintest-rpc1.okex.com:26659',
      accounts,
      chainId: 65,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
    },
    xdai: {
      url: 'https://rpc.xdaichain.com',
      accounts,
      chainId: 100,
      live: true,
      saveDeployments: true,
    },
    tomo: {
      url: 'https://rpc.tomochain.com',
      accounts,
      chainId: 88,
      live: true,
      saveDeployments: true,
    },
    tomotest: {
      url: 'https://rpc.testnet.tomochain.com',
      accounts,
      chainId: 89,
      live: true,
      saveDeployments: true,
      tags: ['staging'],
    },
  },
  paths: {
    artifacts: 'artifacts',
    cache: 'cache',
    deploy: 'deploy',
    deployments: 'deployments',
    imports: 'imports',
    sources: 'contracts',
    tests: 'test',
  },
  preprocess: {
    eachLine: removeConsoleLog((bre) => bre.network.name !== 'hardhat' && bre.network.name !== 'localhost'),
  },
  solidity: {
    version: '0.6.12',
    settings: {
      optimizer: {
        enabled: true,
        runs: 256,
      },
    },
  },
  spdxLicenseIdentifier: {
    overwrite: false,
    runOnCompile: true,
  },
  tenderly: {
    project: process.env.TENDERLY_PROJECT || '',
    username: process.env.TENDERLY_USERNAME || '',
  },
  typechain: {
    outDir: 'types',
    target: 'ethers-v5',
  },
  watcher: {
    compile: {
      tasks: ['compile'],
      files: ['./contracts'],
      verbose: true,
    },
  },
  mocha: {
    timeout: 300000,
    //bail: true,
  },
}

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more
export default config
