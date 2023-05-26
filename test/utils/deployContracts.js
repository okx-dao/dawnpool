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
  const depositNodeManager = await ethers.getContractAt('DepositNodeManager', storageAddr);
  await depositNodeManager.setMinOperatorStakingAmount(ethers.utils.parseEther('2'));
  const { depositContractAddr } = await getChainInfo();
  await dawnStorage.setAddress(keccak256(encodePacked('contract.address', 'DepositContract')), depositContractAddr);
  await dawnStorage.setDeployedStatus();

  // init oracle
  const [owner, oracleMember, otherAccount] = await ethers.getSigners()
  storageAddr = await dawnStorage.getAddress(keccak256(encodePacked('contract.address', 'DawnPoolOracle')));
  const dawnPoolOracle = await ethers.getContractAt('DawnPoolOracle', storageAddr);
  await dawnPoolOracle.initialize(225, 32, 12, 1639659600)
  await dawnPoolOracle.addOracleMember(owner.address)
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
