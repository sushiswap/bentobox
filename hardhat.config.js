// hardhat.config.js

require("@nomiclabs/hardhat-waffle")
require("@nomiclabs/hardhat-solhint")
require("@nomiclabs/hardhat-etherscan")
require("@tenderly/hardhat-tenderly")
require("hardhat-spdx-license-identifier")
require("solidity-coverage")
require("hardhat-gas-reporter")
require("hardhat-abi-exporter")

const { removeConsoleLog } = require("hardhat-preprocessor")
// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners()

  for (const account of accounts) {
    console.log(account.address)
  }
})

task("pairs", "Prints the list of pairs", async () => {
  // ...
})

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  abiExporter: {
    path: "./build/abi",
    clear: true,
    flat: true,
    // only: ['ERC20'],
    // except: ['ERC20']
  },
  // defaultNetwork: "rinkeby",
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS ? true : false,
    currency: "USD",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    excludeContracts: ["contracts/external/", "contracts/libraries/"],
  },
  hardhat: {
    forking: {
      url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
    },
  },
  networks: {
    hardhat: {
      chainId: 31337,
      accounts: [
        {
          privateKey:
            "0x278a5de700e29faae8e40e366ec5012b5ec63d36ec77e8a2417154cc1d25383f",
          balance: "990000000000000000000",
        },
        {
          privateKey:
            "0x7bc8feb5e1ce2927480de19d8bc1dc6874678c016ae53a2eec6a6e9df717bfac",
          balance: "990000000000000000000",
        },
        {
          privateKey:
            "0x94890218f2b0d04296f30aeafd13655eba4c5bbf1770273276fee52cbe3f2cb4",
          balance: "990000000000000000000",
        },
        {
          privateKey:
            "0x12340218f2b0d04296f30aeafd13655eba4c5bbf1770273276fee52cbe3f2cb4",
          balance: "990000000000000000000",
        },
        {
          privateKey:
            "0x043a569345b08ead19d1d4ba3462b30632feba623a2a85a3b000eb97f709f09f",
          balance: "990000000000000000000",
        },
      ],
    },
    // mainnet: {
    //   url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
    //   accounts: [process.env.PRIVATE_KEY],
    //   gasPrice: 120 * 1000000000,
    //   chainId: 1,
    // },
    // ropsten: {
    //   url: `https://ropsten.infura.io/v3/${process.env.INFURA_API_KEY}`,
    //   accounts: [process.env.PRIVATE_KEY],
    //   chainId: 3,
    // },
    // rinkeby: {
    //   url: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
    //   accounts: [process.env.PRIVATE_KEY],
    //   chainId: 4,
    // },
  },
  preprocess: {
    eachLine: removeConsoleLog(
      (bre) =>
        bre.network.name !== "hardhat" && bre.network.name !== "localhost"
    ),
  },
  solidity: {
    version: "0.6.12",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  spdxLicenseIdentifier: {
    overwrite: true,
    runOnCompile: true,
  },
  tenderly: {
    project: process.env.TENDERLY_PROJECT,
    username: process.env.TENDERLY_USERNAME,
  },
}
