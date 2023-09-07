const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');
const { depositBufferedEther, setValidatorUnsafe } = require('../utils/makeSecurityModuleSignature');
const { ethers } = require('hardhat');
const { deployContracts, getDeployedContractAddress } = require('../utils/deployContracts');

const ValidatorStatus = {
  NOT_EXIST: 0,
  WAITING_ACTIVATED: 1,
  VALIDATING: 2,
  EXIT: 3,
  SLASHING: 4,
  //        EXITED,
  UNSAFE: 5,
};

const pubkey1 = '0x957f3a659faa3cdcd21be00a05b7bbca25a41b2f2384166ca5872363c37110b3dedbab1261179338fadc4ff70b4bea57';
const preSignature1 =
  '0xb287fba521351afa11f2572eab9c4292be59288d8f15020c9b6477808302731a0669c31788e9b5a3603896fae7282cb9160acd80e6c73610243df9e0899065b1afa20e4a4449c80f708fe3686d7faf8265f825f10d8e42f8e39e12e70a43a6ca';
const depositSignature1 =
  '0x986059be4ca6b645669604bc9e30adf22ce8cc313e200724b8e6c5fcd79101fea66c5fd0733fe04fa4a683999984006212912ba1d43c9281489dd1a7ece88ad617ad9c89217f72a7af0a2d71874c1c21e3fdb99ff35a807fcc9c46b86897c719';
const pubkey2 = '0x976b8dc5e9390c75d129609634fec912d3d5b2fcb5ef4badb806a68680d11df640cba696619be05896e0705c32db629b';
const preSignature2 =
  '0x82fdddec643c42aff9f6857456bfed799c108c9a8363df95ce51dc95caf1043c1d5c297ae3933a89098f5e40a77113fc0ffb271342d7bc69729128ebe0faf45f61a75a696e7f864810311c03eba7ac03107ab9ddbd73013e64e5bb690b9c2e0c';
const depositSignature2 =
  '0xb609681c7ed74fb18d0395f252a8a3745678a4731184608c0f9df0bfdc78bbb033c95731484215b344bc3b8456958959077c7ca3b8f34142154e78eba535b2615ee0b065cbef4ea92d4a9bddd490cb351253198b7479793a308956c5e220ba7f';

function removePrefix(str) {
  return str.substring(2);
}

async function addValidatorsAndDeposit(nodeManager, account, pubkeys, preSignatures, depositSignatures) {
  await nodeManager.connect(account).registerNodeOperator(account.address);
  const { nodeAddress } = await nodeManager.getNodeOperator(account.address);
  const nodeOperator = await ethers.getContractAt('IDepositNodeOperator', nodeAddress);
  const validatorCount = 2;
  const minOperatorStakingAmount = await nodeManager.getMinOperatorStakingAmount();
  await nodeOperator.connect(account).addValidators(pubkeys, preSignatures, depositSignatures, {
    value: minOperatorStakingAmount.mul(validatorCount),
  });
  return nodeOperator;
}

async function deployDepositNodeManager() {
  // Contracts are deployed using the first signer/account by default
  await deployContracts();
  const nodeManagerAddr = await getDeployedContractAddress('DepositNodeManager');
  const DepositNodeManager = await ethers.getContractFactory('DepositNodeManager');
  const nodeManager = await DepositNodeManager.attach(nodeManagerAddr);
  const [owner, otherAccount] = await ethers.getSigners();
  const dawnDepositAddr = await getDeployedContractAddress('DawnDeposit');
  const DawnDeposit = await ethers.getContractFactory('DawnDeposit');
  const dawnDeposit = await DawnDeposit.attach(dawnDepositAddr);
  await dawnDeposit.stake({ value: ethers.utils.parseEther('60') });
  const depositSecurityModuleAddress = await getDeployedContractAddress('DawnDepositSecurityModule');
  const DawnDepositSecurityModule = await ethers.getContractFactory('DawnDepositSecurityModule');
  const depositSecurityModule = await DawnDepositSecurityModule.attach(depositSecurityModuleAddress);
  return { nodeManager, depositSecurityModule, owner, otherAccount };
}

describe('ActivateValidators', function () {
  it('Should activate validators successfully', async function () {
    const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
    await addValidatorsAndDeposit(
      nodeManager,
      owner,
      pubkey1 + removePrefix(pubkey2),
      preSignature1 + removePrefix(preSignature2),
      depositSignature1 + removePrefix(depositSignature2),
    );
    await depositBufferedEther([0, 1]);
    expect(await nodeManager.getTotalValidatorsCount()).to.equal(2);
    expect(await nodeManager.getTotalActivatedValidatorsCount()).to.equal(2);
    let nodeValidator = await nodeManager['getNodeValidator(uint256)'](0);
    expect(nodeValidator['operator']).to.equal(owner.address);
    expect(nodeValidator['pubkey']).to.equal(pubkey1);
    expect(nodeValidator['status']).to.equal(ValidatorStatus.VALIDATING);
    nodeValidator = await nodeManager['getNodeValidator(uint256)'](1);
    expect(nodeValidator['operator']).to.equal(owner.address);
    expect(nodeValidator['pubkey']).to.equal(pubkey2);
    expect(nodeValidator['status']).to.equal(ValidatorStatus.VALIDATING);
    nodeValidator = await nodeManager['getNodeValidator(uint256)'](2);
    expect(nodeValidator['operator']).to.equal(ethers.constants.AddressZero);
    expect(nodeValidator['pubkey']).to.equal('0x');
    expect(nodeValidator['status']).to.equal(ValidatorStatus.NOT_EXIST);
  });

  describe('SetValidatorUnsafe', function () {
    it('Should set validator unsafe successfully', async function () {
      const { nodeManager, owner, otherAccount } = await loadFixture(deployDepositNodeManager);
      const nodeOperator = await addValidatorsAndDeposit(
        nodeManager,
        owner,
        pubkey1 + removePrefix(pubkey2),
        preSignature1 + removePrefix(preSignature2),
        depositSignature1 + removePrefix(depositSignature2),
      );
      const dawnDepositAddr = await getDeployedContractAddress('DawnDeposit');
      const dawnDeposit = await ethers.getContractAt('DawnDeposit', dawnDepositAddr);
      const pethAmount = await dawnDeposit.getPEthByEther(ethers.utils.parseEther('2'));
      expect((await nodeManager.getNodeOperator(owner.address)).isActive).to.equal(true);
      await expect(setValidatorUnsafe(0, pethAmount))
        .to.emit(nodeManager, 'SigningKeyUnsafe')
        .withArgs(0, owner.address, pubkey1, nodeOperator.address, pethAmount)
        .to.emit(nodeManager, 'NodeOperatorActiveStatusChanged')
        .withArgs(owner.address, false);
      expect((await nodeManager.getNodeOperator(owner.address)).isActive).to.equal(false);
      await expect(nodeManager.setNodeOperatorActiveStatus(owner.address, true))
        .to.emit(nodeManager, 'NodeOperatorActiveStatusChanged')
        .withArgs(owner.address, true);
      await expect(nodeManager.setNodeOperatorActiveStatus(owner.address, false))
        .to.emit(nodeManager, 'NodeOperatorActiveStatusChanged')
        .withArgs(owner.address, false);
      await expect(nodeManager.setNodeOperatorActiveStatus(otherAccount.address, false)).to.be.revertedWithCustomError(
        nodeManager,
        'NotExistOperator',
      );
    });
  });
});
