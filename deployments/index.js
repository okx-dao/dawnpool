const { ethers, artifacts } = require('hardhat');
const { keccak256, encodePacked } = require('web3-utils');

// Storage
const DawnStorage = ethers.getContractFactory('DawnStorage');
let dawnStorageDeploy, dawnStorageInstance;

// Network contracts
const Contracts = {
  // core
  DawnDeposit: ethers.getContractFactory('RewardsVault'),
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

const deployContracts = async function() {
  console.log('****** Start deploy Contracts ******');
  await showAccount().then(() => '');
  console.log('****** Start deploy StorageContracts ******');
  dawnStorageDeploy = await (await DawnStorage).deploy();
  const deployBlock = dawnStorageDeploy.deployTransaction.blockNumber;
  dawnStorageInstance = await dawnStorageDeploy.deployed();
  console.log('Setting deploy.block to ' + deployBlock);
  await dawnStorageInstance.setUint(keccak256(encodePacked('deploy.block')), deployBlock);
  console.log('********************************');
  console.log('dawnStorage contract address is ' + (await dawnStorageInstance.address));
  let dawnInstance, storageAddr;
  for (let Contract in Contracts) {
    console.log('********************************');
    console.log('Contract name is: ' + Contract.toString());
    if(Contracts.hasOwnProperty(Contract)) {
      switch (Contract) {
        case 'DawnDeposit':
          dawnInstance = await (await Contracts[Contract]).deploy(dawnStorageInstance.address);
          break;
        case 'RewardsVault':
          dawnInstance = await (await Contracts[Contract]).deploy(dawnStorageInstance.address);
          break;
        case 'DepositNodeManager':
          dawnInstance = await (await Contracts[Contract]).deploy(dawnStorageInstance.address);
          break;
        default:
          break;
      }
    }
    console.log(`Contract ${Contract} deployed to: ` + dawnInstance.address);
    console.log('\x1b[31m%s\x1b[0m:', '   Set Storage ' + Contract + ' Address');
    console.log('     ' + dawnInstance.address);
    // Register the contract address as part of the network
    await dawnStorageInstance.setBool(keccak256(encodePacked('contract.exists', dawnInstance.address)), true);
    // Register the contract's name by address
    await dawnStorageInstance.setString(keccak256(encodePacked('contract.name', dawnInstance.address)), Contract);
    // Register the contract's address by name
    await dawnStorageInstance.setAddress(keccak256(encodePacked('contract.address', Contract)), dawnInstance.address);
    storageAddr = await dawnStorageInstance.getAddress(keccak256(encodePacked('contract.address', Contract)));
    assert(storageAddr == dawnInstance.address, 'Storage address is not equal to deployed!');
  }
  // Disable direct access to storage now
  await dawnStorageInstance.setDeployedStatus();
  if(await dawnStorageInstance.getDeployedStatus() != true) throw 'Storage Access Not Locked Down!!';

  // Log it
  console.log('\n');
  console.log('\x1b[32m%s\x1b[0m', '  Storage Direct Access For Owner Removed...');
  console.log('\n');
}

async function upgradeContracts() {
  console.log('****** Start upgrade Contracts ******');
  return Contracts;
}

module.exports = {
  deployContracts,
  upgradeContracts,
};
