require("@nomicfoundation/hardhat-toolbox");
const dotenv = require("dotenv");
const path = require("path");

dotenv.config({ path: path.join(__dirname, ".env") });
const NETWORK_URL = process.env.NETWORK_URL || "";
const NETWORK_API_KEY = process.env.NETWORK_API_KEY || "";
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 9999,
      },
    },
  },
  defaultNetwork: 'hardhat',
  networks: {
    localhost: {
      accounts: {
        mnemonic: 'that hockey memory flock solid crunch marine very fruit audit diet basic',
        count: 10
      },
      url: 'http://127.0.0.1:8545',
      chainId: 1337
    },
    hardhat: {
      blockGasLimit: 12e6,
      allowUnlimitedContractSize: true,
      initialBaseFeePerGas: (1e9).toString(), // 1 GWEI
      accounts: {
        mnemonic: 'that hockey memory flock solid crunch marine very fruit audit diet basic',
        count: 10,
        accountsBalance: '1000000000000000000000'
      },
    goerli: {
      url: NETWORK_URL + NETWORK_API_KEY,
      chainId: 5,
      timeout: 60000 * 10,
      },
    },
  },
  gasReporter: {
    enabled: false,
    showTimeSpent: true,
    gasPrice: 20,
    currency: 'USD',
    maxMethodDiff: 25,
    outputFile: 'test-gas-used.log',
  },
  mocha: {
    timeout: 120e3, // 120s
    retries: 1,
  },
};
