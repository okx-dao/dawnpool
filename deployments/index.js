const { ethers, web3 } = require('hardhat');
const { keccak256, encodePacked } = require('web3-utils');
const { assert } = require('chai');
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
  DepositNodeOperatorDeployer: ethers.getContractFactory('DepositNodeOperatorDeployer'),
};

let dawnStorage;

function toColorString(str, c) {
  switch (c) {
    case 'r':
      return '\x1b[31m' + str + '\x1b[0m'; // red
    case 'g':
      return '\x1b[32m' + str + '\x1b[0m'; // green
    case 'y':
      return '\x1b[33m' + str + '\x1b[0m'; // yellow
    default:
      return '\x1b[0m' + str + '\x1b[0m';
  }
}

function toGreen(str) {
  return toColorString(str, 'g');
}
// function toRed(str) { return toColorString(str, 'r') }
function toYellow(str) {
  return toColorString(str, 'y');
}

async function deployDepositContract() {
  const DepositContract = await ethers.getContractFactory('DepositContract');
  const depositContract = await DepositContract.deploy();
  console.log(' depositContract deploying...');
  console.log(' Tx hash: ', toGreen(depositContract.deployTransaction.hash));
  await depositContract.deployed();
  console.log(' depositContract deployed: ', toGreen(depositContract.address));
  return depositContract;
}

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
  console.log(toYellow(' You are currently using the ' + chainName + 'network, chainID ' + chainId));
  return { chainName, depositContractAddr };
}

// Accounts
async function showAccount() {
  const accounts = await ethers.getSigners();
  for (const account of accounts) {
    console.log(' ', toGreen(account.address));
  }
}

const deployContracts = async function () {
  console.log('****** Prints the list of accounts ******');
  await showAccount().then(() => '');
  console.log('');
  console.log('****** Confirm chain info ******');
  await getChainInfo();
  console.log('');
  console.log('****** Start deploy DawnStorage contract ******');
  dawnStorage = await (await DawnStorage).deploy();
  console.log(` Contract DawnStorage deploying...`);
  console.log(' Tx hash: ', toGreen(dawnStorage.deployTransaction.hash));
  await dawnStorage.deployed();
  console.log(` Contract DawnStorage deployed: `, toGreen(dawnStorage.address));
  const deployBlock = dawnStorage.deployTransaction.blockNumber;
  console.log(' Setting deploy.block to ' + deployBlock);
  await dawnStorage.setUint(keccak256(encodePacked('deploy.block')), deployBlock);
  console.log('');
  let dawnInstance, storageAddr, tx;
  for (let Contract in Contracts) {
    if (Contracts.hasOwnProperty.call(Contract)) {
      console.log(`****** Start deploy ${Contract} contract ******`);
      // console.log('Contract name is: ' + Contract.toString());
      switch (Contract) {
        case 'Contract':
          // Do sth else here
          break;
        default:
          dawnInstance = await (await Contracts[Contract]).deploy(dawnStorage.address);
          console.log(` Contract ${Contract} deploying...`);
          console.log(' Tx hash: ', toGreen(dawnInstance.deployTransaction.hash));
          await dawnInstance.deployed();
          console.log(` Contract ${Contract} deployed: `, toGreen(dawnInstance.address));
          break;
      }
      // Register the contract address as part of the network
      console.log(' ** Set storage contract.exists...');
      tx = await dawnStorage.setBool(keccak256(encodePacked('contract.exists', dawnInstance.address)), true);
      console.log(' Tx hash: ', toGreen(tx.hash));
      await tx.wait();
      console.log(' Storage contract.exists set');
      // Register the contract's name by address
      console.log(' ** Set storage contract.name...');
      tx = await dawnStorage.setString(keccak256(encodePacked('contract.name', dawnInstance.address)), Contract);
      console.log(' Tx hash: ', toGreen(tx.hash));
      await tx.wait();
      console.log(' Storage contract.name set');
      // Register the contract's address by name
      console.log(' ** Set storage contract.address...');
      tx = await dawnStorage.setAddress(keccak256(encodePacked('contract.address', Contract)), dawnInstance.address);
      console.log(' Tx hash: ', toGreen(tx.hash));
      await tx.wait();
      console.log(' Storage contract.address set');
      storageAddr = await dawnStorage.getAddress(keccak256(encodePacked('contract.address', Contract)));
      assert(storageAddr == dawnInstance.address, 'Storage address is not equal to deployed!');
    }
  }

  // Disable direct access to storage now
  await dawnStorage.setDeployedStatus();
  console.log('** Removed Storage Direct Access...', toGreen(tx.hash));
  await tx.wait();
  console.log('Storage Direct Access For Owner Removed');
  if ((await dawnStorage.getDeployedStatus()) != true) throw 'Storage Access Not Locked Down!!';
  console.log('');
};

async function upgradeContracts() {
  console.log('****** Start upgrade Contracts ******');
  return Contracts;
}

module.exports = {
  deployContracts,
  upgradeContracts,
};
