const { getDeployedContractAddress } = require('./deployContracts');
const { ethers, web3 } = require('hardhat');
const { ecsign, bufferToHex } = require('ethereumjs-util');

let _depositSecurityModule;
async function getDepositSecurityModule() {
  if (_depositSecurityModule) return _depositSecurityModule;
  const DawnDepositSecurityModule = await ethers.getContractFactory('DawnDepositSecurityModule');
  const securityModuleAddr = await getDeployedContractAddress('DawnDepositSecurityModule');
  _depositSecurityModule = await DawnDepositSecurityModule.attach(securityModuleAddr);
  return _depositSecurityModule;
}

let _activatePrefix;
async function getActivatePrefix() {
  if (_activatePrefix) return _activatePrefix;
  const depositSecurityModule = await getDepositSecurityModule();
  _activatePrefix = await depositSecurityModule.getAttestMessagePrefix();
  return _activatePrefix;
}

let _setUnsafePrefix;
async function getUnsafePrefix() {
  if (_setUnsafePrefix) return _setUnsafePrefix;
  const depositSecurityModule = await getDepositSecurityModule();
  _setUnsafePrefix = await depositSecurityModule.getUnsafeMessagePrefix();
  return _setUnsafePrefix;
}

async function getLatestBlock() {
  const latestBlock = await web3.eth.getBlock('latest');
  const blockNumber = latestBlock.number;
  const blockHash = latestBlock.hash;
  return { blockNumber, blockHash };
}

async function getDepositRoot() {
  const DepositContract = await ethers.getContractFactory('DepositContract');
  const depositContractAddr = await getDeployedContractAddress('DepositContract');
  const depositContract = await DepositContract.attach(depositContractAddr);
  return await depositContract.get_deposit_root();
}

function toEip2098({ v, r, s }) {
  const vs = s;
  if (vs[0] >> 7 === 1) {
    throw new Error(`invalid signature 's' value`);
  }
  vs[0] |= v % 27 << 7; // set the first bit of vs to the v parity bit
  return { r: bufferToHex(r), vs: bufferToHex(vs) };
}

const privateKey = 'ee20bd4680de25a3d54304514bc44a62493225c9d1239c8ec320c70b1fdaf486';

async function depositBufferedEther(indexes) {
  const prefix = await getActivatePrefix();
  const { blockNumber, blockHash } = await getLatestBlock();
  const depositRoot = await getDepositRoot();
  const encoded = ethers.utils.solidityPack(
    ['bytes32', 'uint256', 'bytes32', 'bytes32', 'uint256[]'],
    [prefix, blockNumber, blockHash, depositRoot, indexes],
  );
  const messageHash = web3.utils.soliditySha3(encoded);
  const signature = ecsign(Buffer.from(messageHash.substring(2), 'hex'), Buffer.from(privateKey, 'hex'));
  const { r, vs } = toEip2098(signature);
  const depositSecurityModule = await getDepositSecurityModule();
  return await depositSecurityModule.depositBufferedEther(blockNumber, blockHash, depositRoot, indexes, [{ r, vs }]);
}

async function setValidatorUnsafe(index, slashAmount) {
  const prefix = await getUnsafePrefix();
  const { blockNumber } = await getLatestBlock();
  const encodedData = ethers.utils.solidityPack(
    ['bytes32', 'uint256', 'uint256', 'uint256'],
    [prefix, blockNumber, index, slashAmount],
  );
  const messageHash = web3.utils.soliditySha3(encodedData);
  const signature = ecsign(Buffer.from(messageHash.substring(2), 'hex'), Buffer.from(privateKey, 'hex'));
  const { r, vs } = toEip2098(signature);
  const depositSecurityModule = await getDepositSecurityModule();
  return await depositSecurityModule.setValidatorUnsafe(blockNumber, index, slashAmount, { r, vs });
}

module.exports = {
  depositBufferedEther,
  setValidatorUnsafe,
};
