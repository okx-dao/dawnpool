const { ethers, web3 } = require('hardhat');
const { keccak256, encodePacked } = require('web3-utils');
const { readJSON } = require('../../scripts/helpers/fs');
const { deployContracts } = require('../utils/deployContracts');

let dawnStorage, dawnDeposit, nodeManager, rewardsVault;

async function getDawnStorageAddress() {
  const chainId = await web3.eth.getChainId();
  let chainName;
  switch (chainId) {
    case 1:
      chainName = 'mainnet';
      break;
    case 5:
      chainName = 'goerli';
      break;
    default:
      chainName = 'local';
      break;
  }
  console.log('\x1b[33m%s\x1b[0m', 'You are currently using the ' + chainName + 'network, chainID ' + chainId);
  if (chainName && chainName != 'local') {
    console.log('Reading DawnDeposit contract address from json file...');
    const deployed = await readJSON(`../../deployed-${chainName}.json`);
    const dawnStorageAddr = deployed['dawnStorage'];
    console.log('DawnDeposit contract address: ' + `\x1b[32m${dawnStorageAddr}\x1b[0m`);
    return dawnStorageAddr;
  } else {
    return (await deployContracts()).address;
  }
}

async function getAddress(contractName) {
  return await dawnStorage.getAddress(keccak256(encodePacked('contract.address', contractName)));
}

async function getDeployedContracts() {
  const DawnStorage = await ethers.getContractFactory('DawnStorage');
  const DawnDeposit = await ethers.getContractFactory('DawnDeposit');
  const DepositNodeManager = await ethers.getContractFactory('DepositNodeManager');
  const RewardsVault = await ethers.getContractFactory('RewardsVault');

  if (!dawnStorage) {
    const dawnStorageAddr = await getDawnStorageAddress();
    dawnStorage = await DawnStorage.attach(dawnStorageAddr);
    dawnDeposit = await DawnDeposit.attach(await getAddress('DawnDeposit'));
    nodeManager = await DepositNodeManager.attach(await getAddress('DepositNodeManager'));
    rewardsVault = await RewardsVault.attach(await getAddress('RewardsVault'));
  }
  return { dawnStorage, dawnDeposit, nodeManager, rewardsVault };
}

module.exports = {
  getDeployedContracts,
};
