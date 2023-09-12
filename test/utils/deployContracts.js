const { ethers, web3 } = require('hardhat');
const { keccak256, encodePacked } = require('web3-utils');

// Storage
const DawnStorage = ethers.getContractFactory('DawnStorage');
// Network contracts
const Contracts = {
  // core
  DawnDeposit: ethers.getContractFactory('DawnDeposit'),
  DawnInsurance: ethers.getContractFactory('DawnInsurance'),
  DawnTreasury: ethers.getContractFactory('DawnTreasury'),
  // oracle
  DawnPoolOracle: ethers.getContractFactory('DawnPoolOracle'),
  // Vault
  RewardsVault: ethers.getContractFactory('RewardsVault'),
  // Node operator manager
  DepositNodeManager: ethers.getContractFactory('DepositNodeManager'),
  DepositNodeOperatorDeployer: ethers.getContractFactory('DepositNodeOperatorDeployer'),
  // secure module
  AddressSetStorage: ethers.getContractFactory('AddressSetStorage'),
  AddressQueueStorage: ethers.getContractFactory('AddressQueueStorage'),
  DawnDepositSecurityModule: ethers.getContractFactory('DawnDepositSecurityModule'),
  Burner: ethers.getContractFactory('Burner'),
  HashConsensus: ethers.getContractFactory('HashConsensus'),
  ValidatorsExitBusOracle: ethers.getContractFactory('ValidatorsExitBusOracle'),
};

let dawnStorage;

async function getChainInfo() {
  const chainId = await web3.eth.getChainId();
  let chainName, depositContractAddr;
  switch (chainId) {
    case 1:
      chainName = 'mainnet';
      depositContractAddr = '0x00000000219ab540356cBB839Cbe05303d7705Fa';
      break;
    case 5:
      chainName = 'goerli';
      depositContractAddr = '0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b';
      break;
    case 31337:
      chainName = 'local';
      depositContractAddr = (await deployDepositContract()).address;
      break;
    case 32382:
      chainName = 'dev';
      depositContractAddr = '0x4242424242424242424242424242424242424242';
      break;
    default:
      break;
  }
  return { chainName, depositContractAddr };
}

async function deployDepositContract() {
  const DepositContract = await ethers.getContractFactory('DepositContract');
  return await DepositContract.deploy();
}

async function deployContracts() {
  dawnStorage = await (await DawnStorage).deploy();
  await dawnStorage.deployed();
  const { chainName, depositContractAddr } = await getChainInfo();
  const [owner] = await ethers.getSigners();
  let dawnInstance, storageAddr;
  for (let Contract in Contracts) {
    switch (Contract) {
      case 'DawnDepositSecurityModule':
        dawnInstance = await (await Contracts[Contract]).deploy(dawnStorage.address, depositContractAddr);
        await dawnInstance.deployed();
        break;
      default:
        dawnInstance = await (await Contracts[Contract]).deploy(dawnStorage.address);
        await dawnInstance.deployed();
        break;
    }
    await dawnStorage.setAddress(keccak256(encodePacked('contract.address', Contract)), dawnInstance.address);
    await dawnStorage.setBool(keccak256(encodePacked('contract.exists', dawnInstance.address)), true);
  }

  // 初始化 dawn deposit
  dawnStorage.setUint(keccak256('dawnDeposit.fee'), 1000);
  dawnStorage.setUint(keccak256('dawnDeposit.treasuryFee'), 5000);
  dawnStorage.setUint(keccak256('dawnDeposit.nodeOperatorFee'), 5000);

  // 初始化 DepositNodeManager 参数
  storageAddr = await getDeployedContractAddress('DepositNodeManager');
  const depositNodeManager = await ethers.getContractAt('DepositNodeManager', storageAddr);
  await depositNodeManager.setMinOperatorStakingAmount(ethers.utils.parseEther('2'));
  await dawnStorage.setAddress(keccak256(encodePacked('contract.address', 'DepositContract')), depositContractAddr);

  // init oracle
  storageAddr = await getDeployedContractAddress('DawnPoolOracle');
  const dawnPoolOracle = await ethers.getContractAt('DawnPoolOracle', storageAddr);
  let epochsPerFrame = 225;
  if (chainName == 'local') {
    epochsPerFrame = 1;
  }
  await dawnPoolOracle.initialize(epochsPerFrame, 32, 12, 1639659600, 0);

  // init oracle
  storageAddr = await getDeployedContractAddress('ValidatorsExitBusOracle');
  const validatorsExitBusOracle = await ethers.getContractAt('ValidatorsExitBusOracle', storageAddr);
  await validatorsExitBusOracle.initialize(epochsPerFrame, 32, 12, 1639659600, 0);

  // init secure module
  storageAddr = await getDeployedContractAddress('DawnDepositSecurityModule');
  const depositSecurityModule = await ethers.getContractAt('DawnDepositSecurityModule', storageAddr);
  await depositSecurityModule.initilize(100, 1, 1);
  await depositSecurityModule.addGuardian(owner.address, 1);

  // init HashConsensus
  storageAddr = await getDeployedContractAddress('HashConsensus');
  const hashConsensus = await ethers.getContractAt('HashConsensus', storageAddr);
  await hashConsensus.initialize();
  await hashConsensus.addOracleMember(owner.address);

  // 最后调用此接口，调用后权限受到很大限制
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
  getChainInfo,
  deployContracts,
  upgradeContracts,
  getDeployedContractAddress,
};
