const { ethers } = require('hardhat');
const { getDeployedContracts } = require('./dawn_storage');
const { BigNumber } = require('ethers');
const { assert } = require('chai');

async function registerNodeOperatorIfNotRegistered() {
  const { nodeManager } = await getDeployedContracts();
  const owner = await ethers.getSigner();
  let nodeOperator = await nodeManager.getNodeOperator(owner.address);
  let tx;
  if (nodeOperator['nodeAddress'] == ethers.constants.AddressZero) {
    tx = await nodeManager.registerNodeOperator(owner.address);
  }
  return { nodeManager, tx };
}

async function addValidators(pubkeys, preSignatures, depositSignatures) {
  const { dawnDeposit, nodeManager } = await getDeployedContracts();
  const owner = await ethers.getSigner();
  const { nodeAddress, isActive } = await nodeManager.getNodeOperator(owner.address);
  assert(nodeAddress != ethers.constants.AddressZero, 'Operator not registered!');
  assert(isActive == true, 'Operator is inactive!');
  const nodeOperator = await ethers.getContractAt('DepositNodeOperator', nodeAddress);
  const PUBKEY_LEN = 48 * 2;
  const count = (pubkeys.length - 2) / PUBKEY_LEN;
  const minStakingAmount = (await nodeManager.getMinOperatorStakingAmount()).mul(count);
  const pethERC20 = await ethers.getContractAt('IERC20', dawnDeposit.address);
  const balance = await dawnDeposit.getEtherByPEth(await pethERC20.balanceOf(nodeOperator.address));
  const requireAdded = minStakingAmount.gt(balance) ? minStakingAmount.sub(balance) : BigNumber.from(0);
  let tx;
  if (requireAdded.gt(0)) {
    tx = await nodeOperator.addValidators(pubkeys, preSignatures, depositSignatures, {
      value: requireAdded,
    });
  } else {
    tx = await nodeOperator.addValidators(pubkeys, preSignatures, depositSignatures);
  }
  return { nodeManager, nodeOperator, tx };
}

async function activateValidators(indexes) {
  const { nodeManager } = await getDeployedContracts();
  const owner = await ethers.getSigner();
  const { nodeAddress, isActive } = await nodeManager.getNodeOperator(owner.address);
  assert(nodeAddress != ethers.constants.AddressZero, 'Operator not registered!');
  assert(isActive == true, 'Operator is inactive!');
  const tx = await nodeManager.activateValidators(indexes);
  return { nodeManager, tx };
}

async function claimRewards() {
  const { nodeManager, dawnDeposit } = await getDeployedContracts();
  const owner = await ethers.getSigner();
  const { nodeAddress, isActive } = await nodeManager.getNodeOperator(owner.address);
  assert(nodeAddress != ethers.constants.AddressZero, 'Operator not registered!');
  assert(isActive == true, 'Operator is inactive!');
  const DepositNodeOperator = await ethers.getContractFactory('DepositNodeOperator');
  const nodeOperator = await DepositNodeOperator.attach(nodeAddress);
  const claimableRewards = await nodeOperator.getClaimableRewards();
  assert(claimableRewards.gt(0), 'No rewards can be claimed!');
  const tx = await nodeOperator.claimRewards();
  return { nodeManager, nodeOperator, dawnDeposit, claimableRewards, tx };
}

module.exports = {
  registerNodeOperatorIfNotRegistered,
  addValidators,
  activateValidators,
  claimRewards,
};
