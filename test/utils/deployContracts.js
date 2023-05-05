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

let dawnStorage;

async function deployContracts() {
  dawnStorage = await (await DawnStorage).deploy();
  await dawnStorage.deployed();
  let dawnInstance, storageAddr;
  for (let Contract in Contracts) {
    switch (Contract) {
      case 'Contract':
        // Do sth else here
        break;
      default:
        dawnInstance = await (await Contracts[Contract]).deploy(dawnStorage.address);
        await dawnInstance.deployed();
        break;
    }
    await dawnStorage.setAddress(keccak256(encodePacked('contract.address', Contract)), dawnInstance.address);
    await dawnStorage.setBool(keccak256(encodePacked('contract.exists', dawnInstance.address)), true);
  }
  // 初始化 DepositNodeManager 参数
  storageAddr = await dawnStorage.getAddress(keccak256(encodePacked('contract.address', 'DepositNodeManager')));
  const depositNodeManager = await ethers.getContractAt('IDepositNodeManager', storageAddr);
  await depositNodeManager.setMinOperatorStakingAmount(ethers.utils.parseEther('2'));
  await dawnStorage.setDeployedStatus();
  return dawnStorage;
}

async function upgradeContracts() {
  return Contracts;
}

async function getDeployedContractAddress(contractName) {
  return await dawnStorage.getAddress(keccak256(encodePacked('contract.address', contractName)));
}

module.exports = {
  deployContracts,
  upgradeContracts,
  getDeployedContractAddress,
};
