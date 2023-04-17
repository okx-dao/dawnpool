const { ethers } = require('hardhat');
const { keccak256, encodePacked } = require('web3-utils');

// Storage
const DawnStorage = ethers.getContractFactory('DawnStorage');
// Network contracts
const Contracts = {
  // core
  DawnDeposit: ethers.getContractFactory('DawnDeposit'),
  // Vault
  RewardsVault: ethers.getContractFactory('RewardsVault'),
  // Node operator manager
  DepositNodeManager: ethers.getContractFactory('DepositNodeManager'),
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
  const dawnStorage = await (await DawnStorage).deploy();
  await dawnStorage.deployed();
  console.log('dawnStorage contract address is ' + (await dawnStorage.address));
  let dawnInstance, storageAddr;
  for (let Contract in Contracts) {
    console.log('********************************');
    console.log('Contract name is: ' + Contract.toString());
    switch (Contract) {
      case 'Contract':
      // Do sth else here
      default:
        dawnInstance = await (await Contracts[Contract]).deploy(dawnStorage.address);
        await dawnInstance.deployed();
        break;
    }
    await dawnStorage.setAddress(keccak256(encodePacked('contract.address', Contract)), dawnInstance.address);
    storageAddr = await dawnStorage.getAddress(keccak256(encodePacked('contract.address', Contract)));
    assert(storageAddr == dawnInstance.address, 'Storage address is not equal to deployed!');
    console.log(`Contract ${Contract} deployed to: ` + dawnInstance.address);
  }
  await dawnStorage.setDeployedStatus();
  return dawnStorage;
}

async function upgradeContracts() {
  console.log('****** Start upgrade Contracts ******');
  return Contracts;
}

module.exports = {
  deployContracts,
  upgradeContracts,
};
