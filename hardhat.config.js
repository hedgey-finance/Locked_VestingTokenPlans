require('@nomiclabs/hardhat-etherscan');
require('@nomiclabs/hardhat-waffle');
require('hardhat-gas-reporter');
require('solidity-coverage');
require('hardhat-deploy');
require("dotenv").config();


module.exports = {
  solidity: {
    version: '0.8.19',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
  gasReporter: {
    currency: 'USD',
    coinmarketcap: process.env.COINMARKETCAP,
    gasPriceApi: 'https://api.etherscan.io/api?module=proxy&action=eth_gasPrice',
    gasPrice: 40,
  },
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_URL,
      accounts: [process.env.TEST_DEPLOYER_PRIVATE_KEY],
    },
    goerli: {
      url: process.env.GOERLI_URL,
      accounts: [process.env.TEST_DEPLOYER_PRIVATE_KEY],
    },
    mainnet: {
      url: process.env.MAINNET_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
    },
    gnosis: {
      url: process.env.GNOSIS_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
      //chainId: process.env.GNOSIS_CHAINID,
    },
    arbitrumOne: {
      url: process.env.ARBITRUM_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
      //chainId: process.env.ARBITRUM_CHAINID,
    },
    polygon: {
      url: process.env.POLYGON_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
      //chainId: process.env.POLYGON_CHAINID,
      gasPrice: 200000000000,
    },
    opera: {
      url: process.env.FANTOM_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
      //chainId: process.env.FANTOM_CHAINID,
    },
    avalanche: {
      url: process.env.AVALANCHE_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
      //chainId: process.env.AVALANCHE_CHAINID,
    },
    bsc: {
      url: process.env.BSC_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
      //chainId: process.env.BSC_CHAINID,
    },
    optimisticEthereum: {
      url: process.env.OPTIMISM_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
      //chainId: process.env.OPTIMISM_CHAINID,
    },
    harmony: {
      url: process.env.HARMONY_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
      //chainId: process.env.HARMONY_CHAINID,
    },
    boba: {
      url: process.env.BOBA_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
      //chainId: process.env.BOBA_CHAINID,
    },
    aurora: {
      url: process.env.AURORA_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
      //chainId: process.env.AURORA_CHAINID,
    },
    oec: {
      url: process.env.OEC_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
      //chainId: process.env.OEC_CHAINID,
    },
    evmos: {
      url: process.env.EVMOS_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
      //chainId: process.env.EVMOS_CHAINID,
    },
    celo: {
      url: process.env.CELO_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
      //chainId: process.env.CELO_CHAINID,
    }
  },
  etherscan: {
    customChains: [
      {
        network: "gnosis",
        chainId: process.env.GNOSIS_CHAINID,
        urls: {
          apiURL: "https://api.gnosisscan.io/api",
          browserURL: "https://gnosisscan.io/", 
        }
      },
      {
        network: "harmony",
        chainId: process.env.HARMONY_CHAINID,
        urls: {
          browserURL: "https://explorer.aurora.dev/",
          apiURL: ''
        }
      },
      {
        network: "boba",
        chainId: process.env.BOBA_CHAINID,
        urls: {
          apiURL: 'https://api.bobascan.com/',
          browserURL: 'https://bobascan.com'
        }
      }
    ],
    apiKey: {
      sepolia: process.env.ETHERSCAN_APIKEY,
      goerli: process.env.ETHERSCAN_APIKEY,
      mainnet: process.env.ETHERSCAN_APIKEY,
      gnosis: process.env.GNOSIS_APIKEY,
      arbitrumOne: process.env.ARBITRUM_APIKEY,
      polygon: process.env.POLYGON_APIKEY,
      opera: process.env.FANTOM_APIKEY,
      avalanche: process.env.AVALANCHE_APIKEY,
      bsc: process.env.BSC_APIKEY,
      optimisticEthereum: process.env.OPTIMISM_APIKEY,
      harmony: process.env.HARMONY_APIKEY,
      boba: process.env.BOBA_APIKEY,
      aurora: process.env.AURORA_APIKEY,
      // oec: process.env.OEC_APIKEY,
      // evmos: process.env.EVMOS_APIKEY,
      // celo: process.env.CELO_APIKEY,
    },
  },
};
