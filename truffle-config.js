const HDWalletProvider = require("@truffle/hdwallet-provider");

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 8545,
      gasPrice: 1 * 1000000000,
      gasLimit: 10000000,
      network_id: "*",
    },
    rinkeby: {
      provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, "https://rinkeby.infura.io/v3/" + process.env.INFURA_KEY),
      gasPrice: 5 * 1000000000,
      gasLimit: 10000000,
      network_id: 4,
      skipDryRun: true,
    },
    goerli: {
      provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, "https://goerli.infura.io/v3/" + process.env.INFURA_KEY),
      gasPrice: 5 * 1000000000,
      gasLimit: 10000000,
      network_id: 5,
      skipDryRun: true,
    },
    kovan: {
      provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, "https://kovan.infura.io/v3/" + process.env.INFURA_KEY),
      gasPrice: 2.5 * 1000000000,
      gasLimit: 10000000,
      network_id: 42,
      skipDryRun: true,
    },
    sokol: {
      provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, "https://sokol.poa.network"),
      gasPrice: 1 * 1000000000,
      network_id: 77,
      skipDryRun: true,
    },
    xdai: {
      provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, "https://xdai-archive.blockscout.com"),
      gasPrice: 1 * 1000000000,
      network_id: 100,
    },
    matic: {
      provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, "https://rpc-mainnet.matic.network"),
      gasPrice: 1 * 1000000000,
      network_id: 137,
    },
    mainnet: {
      provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, "https://mainnet.infura.io/v3/" + process.env.INFURA_KEY),
      gasPrice: 175 * 1000000000,
      network_id: 1,
      skipDryRun: true,
    },
  },

  compilers: {
    solc: {
      version: "0.7.6",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        },
      }
    },
  },

  plugins: [
    'truffle-source-verify'
  ],

  api_keys: {
    etherscan: process.env.ETHERSCAN_KEY
  }
};