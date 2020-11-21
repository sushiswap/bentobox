var HDWalletProvider = require("@truffle/hdwallet-provider");
var private_key = process.env.key;
var infuraKey = process.env.infura;
var etherscanKey = process.env.etherscan;

module.exports = {
  api_keys: {
    etherscan: etherscanKey
  },
  networks: {
    mainnet: {
      provider: function () {
        return new HDWalletProvider({
          privateKeys: [private_key],
          providerOrUrl: "https://mainnet.infura.io/v3/" + infuraKey
        });
      },
      gasPrice: 60 * 1000000000,
      network_id: 1
    },
    ropsten: {
      provider: function () {
        return new HDWalletProvider({
          privateKeys: [private_key],
          providerOrUrl: "https://ropsten.infura.io/v3/" + infuraKey
        });
      },
      network_id: 3
    },
    rinkeby: {
      provider: function () {
        return new HDWalletProvider({
          privateKeys: [private_key],
          providerOrUrl: "https://rinkeby.infura.io/v3/" + infuraKey
        });
      },
      network_id: 4
    },
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*"
    },
    test: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*"
    },
  },
  compilers: {
    solc: {
      version: "0.6.12",    // Fetch exact version from solc-bin (default: truffle's version)
      settings: {          // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200
        },
      },
    },
  },
  plugins: [
    'truffle-plugin-verify'
  ]
};
