require('@nomicfoundation/hardhat-toolbox');
require('@nomiclabs/hardhat-ethers');
require('@openzeppelin/hardhat-upgrades');
require('@nomiclabs/hardhat-truffle5');
require('solidity-coverage');
require('hardhat-gas-reporter');
require('hardhat-contract-sizer');
require('hardhat-abi-exporter');
require('@nomiclabs/hardhat-etherscan');

const dotenv = require('dotenv');
const path = require('path');
const { task, extendEnvironment } = require('hardhat/config');
const { gray, yellow } = require('chalk');

dotenv.config({ path: path.join(__dirname, '.env') });
const OPTIMIZER_RUNS = 5000000;
const NETWORK_URL = process.env.NETWORK_URL || '';
const NETWORK_API_KEY = process.env.NETWORK_API_KEY || '';
const log = (...text) => console.log(gray(...['└─> [DEBUG]'].concat(text)));

extendEnvironment(hre => {
  hre.log = log;
});

function optimizeIfRequired({ hre, taskArguments: { optimizer } }) {
  if (optimizer || hre.optimizer) {
    // only show message once if re-run
    if (hre.optimizer === undefined) {
      log(gray('Adding optimizer, runs', yellow(OPTIMIZER_RUNS.toString())));
    }

    // Use optimizer (slower) but simulates real contract size limits and gas usage
    hre.config.solidity.compilers[0].settings.optimizer = {
      enabled: true,
      runs: OPTIMIZER_RUNS,
    };
    hre.config.networks.hardhat.allowUnlimitedContractSize = false;
  } else {
    if (hre.optimizer === undefined) {
      log(gray('Optimizer disabled. Unlimited contract sizes allowed.'));
    }
    hre.config.solidity.compilers[0].settings.optimizer = { enabled: false };
    hre.config.networks.hardhat.allowUnlimitedContractSize = true;
  }

  // flag here so that if invoked via "hardhat test" the argument will persist to the compile stage
  hre.optimizer = !!optimizer;
}

task('compile')
  .addFlag('optimizer', 'Compile with the optimizer')
  .setAction(async (taskArguments, hre, runSuper) => {
    optimizeIfRequired({ hre, taskArguments });
    await runSuper(taskArguments);
  });

task('verify')
  .addFlag('optimizer', 'Compile with the optimizer')
  .setAction(async (taskArguments, hre, runSuper) => {
    optimizeIfRequired({ hre, taskArguments });
    await runSuper(taskArguments);
  });

task('accounts', 'Prints the list of accounts', async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();
  console.log('Prints the list of accounts is: ');
  for (const account of accounts) {
    console.log(account.address);
  }
});
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: '0.8.17',
    settings: {
      optimizer: {
        enabled: true,
        runs: 9999,
      },
    },
  },
  defaultNetwork: 'hardhat',
  networks: {
    dev: {
      chainId: 32382,
      url: 'http://127.0.0.1:8545',
      accounts: ['0x2e0834786285daccd064ca17f1654f67b4aef298acbb82cef9ec422fb4975622']
    },
    ganache: {
      url: 'http://127.0.0.1:7545',
      gas: 7000000,
    },
    hardhat: {
      blockGasLimit: 12e6,
      allowUnlimitedContractSize: true,
      initialBaseFeePerGas: (1e9).toString(), // 1 GWEI
      accounts: {
        mnemonic: 'that hockey memory flock solid crunch marine very fruit audit diet basic',
        count: 10,
        accountsBalance: '1000000000000000000000',
      },
    },
    goerli: {
      url: NETWORK_URL + NETWORK_API_KEY,
      chainId: 5,
      timeout: 60000 * 10,
      accounts: {
        mnemonic: 'that hockey memory flock solid crunch marine very fruit audit diet basic',
      },
    },
    mainnet: {
      url: NETWORK_URL + NETWORK_API_KEY,
      chainId: 1,
      timeout: 60000 * 10,
      accounts: {
        mnemonic: 'that hockey memory flock solid crunch marine very fruit audit diet basic',
      },
    },
  },
  throwOnTransactionFailures: true,
  gasReporter: {
    enabled: false,
    showTimeSpent: true,
    gasPrice: 20,
    currency: 'USD',
    maxMethodDiff: 25,
    excludeContracts: ['mocks/'],
    outputFile: 'test-gas-used.log',
  },
  etherscan: {
    apiKey: 'api key goes here',
  },
  mocha: {
    timeout: 120e3, // 120s
    retries: 1,
  },
};
