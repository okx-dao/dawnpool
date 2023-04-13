const { ethers } = require('hardhat');
const { keccak256, encodePacked } = require('web3-utils');

// Storage
const dawnStorage = ethers.getContractFactory('DawnStorage');
// Network contracts
const contracts = {
  // token
  dawnTokenPETH: ethers.getContractFactory('DawnTokenPETH'),
  // Vault
  dawnValut: ethers.getContractFactory('DawnVault'),
};

// Accounts
async function showAccount() {
  const accounts = await ethers.getSigners();
  console.log('Prints the list of accounts is: ');
  for (const account of accounts) {
    console.log(account.address);
  }
}

async function deployContracts() {
  console.log('****** Start deploy Contracts ******');
  await showAccount().then(() => '');
  console.log('********************************');
  let dawnStorageInstance = await (await dawnStorage).deploy();
  await dawnStorageInstance.deployed();
  console.log('dawnStorage contract addrdess is ' + (await dawnStorageInstance.address));
  let dawnInstance;
  for (let contract in contracts) {
    console.log('********************************');
    console.log('contracts name is ' + contract.toString());
    switch (contract) {
      case 'dawnTokenPETH':
        dawnInstance = await (await contracts[contract]).deploy();
        await dawnInstance.deployed();
        console.log('dawnTokenPETH contract addrdess is ' + dawnInstance.address);
        break;
      case 'dawnValut':
        dawnInstance = await (await contracts[contract]).deploy(dawnStorageInstance.address);
        await dawnInstance.deployed();
        console.log('dawnValut contract addrdess is ' + dawnInstance.address);
        break;
      default:
        break;
    }
    console.log('contracts[contract] is ' + dawnInstance.address);

    await dawnStorageInstance.setAddress(keccak256(encodePacked('contract.address', contract)), dawnInstance.address);
    console.log(
      'dawnStorageInstance getAddress is :' +
        (await dawnStorageInstance.getAddress(keccak256(encodePacked('contract.address', contract)))),
    );
  }
  return contracts;
}

async function upgradeContracts() {
  console.log('****** Start upgrade Contracts ******');
  return contracts;
}

module.exports = {
  deployContracts,
  upgradeContracts,
};
