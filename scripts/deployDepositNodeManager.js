const { ethers, web3 } = require('hardhat');
const { keccak256, encodePacked } = require('web3-utils');
const { readJSON } = require('./helpers/fs');

// Storage
const DawnStorage = ethers.getContractFactory('DawnStorage');

let dawnStorage;
const CONTRACT = 'DepositNodeManager';

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

async function getChainInfo() {
  const chainId = await web3.eth.getChainId();
  let chainName, depositContractAddr;
  switch (chainId) {
    case 1:
      chainName = 'mainnet';
      break;
    case 5:
      chainName = 'goerli';
      break;
    default:
      break;
  }
  console.log(toYellow(' You are currently using the ' + chainName + 'network, chainID ' + chainId));
  return { chainName };
}

// Accounts
async function showAccount() {
  const accounts = await ethers.getSigners();
  for (const account of accounts) {
    console.log(' ', toGreen(account.address));
  }
}

const getDawnStorage = async function() {
  const {chainName} = await getChainInfo();
  if (chainName && chainName != 'local') {
    console.log('Reading DawnDeposit contract address from json file...');
    const deployed = await readJSON(`../../deployed-${chainName}.json`);
    const dawnStorageAddress = deployed['dawnStorage'];
    console.log('DawnDeposit contract address: ' + `\x1b[32m${dawnStorageAddress}\x1b[0m`);
    dawnStorage = await (await DawnStorage).attach(dawnStorageAddress);
  }
}

const deployDepositNodeManager = async function () {
  console.log('****** Prints the list of accounts ******');
  await showAccount().then(() => '');
  console.log('');
  console.log('****** Confirm chain info ******');
  await getChainInfo();
  console.log('');
  await getDawnStorage();
  console.log('DawnStorage deployed to: ', toGreen());
  console.log('');
  let dawnInstance, storageAddr, tx;
  const contract = await ethers.getContractFactory(CONTRACT);
  dawnInstance = await contract.deploy(dawnStorage.address);
  console.log(` Contract ${CONTRACT} deploying...`);
  console.log(' Tx hash: ', toGreen(dawnInstance.deployTransaction.hash));
  await dawnInstance.deployed();
  console.log(` Contract ${CONTRACT} deployed: `, toGreen(dawnInstance.address));
// Register the contract address as part of the network
  console.log(' ** Set storage contract.exists...');
  tx = await dawnStorage.setBool(keccak256(encodePacked('contract.exists', dawnInstance.address)), true);
  console.log(' Tx hash: ', toGreen(tx.hash));
  await tx.wait();
  console.log(' Storage contract.exists set');
// Register the contract's address by name
  console.log(' ** Set storage contract.address...');
  tx = await dawnStorage.setAddress(keccak256(encodePacked('contract.address', CONTRACT)), dawnInstance.address);
  console.log(' Tx hash: ', toGreen(tx.hash));
  await tx.wait();
  console.log(' Storage contract.address set');
  storageAddr = await dawnStorage.getAddress(keccak256(encodePacked('contract.address', CONTRACT)));
  assert(storageAddr == dawnInstance.address, 'Storage address is not equal to deployed!');
  console.log('');
};

deployDepositNodeManager()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

