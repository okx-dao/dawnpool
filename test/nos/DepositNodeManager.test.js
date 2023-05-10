const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { anyValue } = require('@nomicfoundation/hardhat-chai-matchers/withArgs');
const { expect } = require('chai');
const { ethers } = require('hardhat');
const { deployContracts, getDeployedContractAddress } = require('../utils/deployContracts');

describe('DepositNodeManager', function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
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
    dawnDeposit.stake({ value: ethers.utils.parseEther('60') });
    return { nodeManager, owner, otherAccount };
  }

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

  describe('Deployment', function () {
    it('Should deploy succeeded', async function () {
      const { nodeManager } = await loadFixture(deployDepositNodeManager);
      expect(nodeManager.address).to.not.equal(ethers.constants.AddressZero);
    });
  });

  describe('RegisterNodeOperator', function () {
    it('Should deploy a node operator contract', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await nodeManager.registerNodeOperator();
      const { nodeAddress, isActive } = await nodeManager.getNodeOperator(owner.address);
      expect(nodeAddress).to.not.equal(ethers.constants.AddressZero);
      expect(isActive).to.equal(true);
    });

    it('Should deploy node operator contract to different addresses', async function () {
      const { nodeManager, owner, otherAccount } = await loadFixture(deployDepositNodeManager);
      await nodeManager.registerNodeOperator();
      const { nodeAddress } = await nodeManager.getNodeOperator(owner.address);
      await nodeManager.connect(otherAccount).registerNodeOperator();
      const { nodeAddress2 } = await nodeManager.getNodeOperator(otherAccount.address);
      expect(nodeAddress).to.not.equal(nodeAddress2);
    });

    it('Should revert if register repeatedly', async function () {
      const { nodeManager } = await loadFixture(deployDepositNodeManager);
      await nodeManager.registerNodeOperator();
      await expect(nodeManager.registerNodeOperator()).to.be.revertedWith('Operator already exist!');
    });

    it('Should emit an event on register node operator', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await expect(nodeManager.registerNodeOperator())
        .to.emit(nodeManager, 'NodeOperatorRegistered')
        .withArgs(owner.address, anyValue); // We accept any value as `when` arg
    });
  });

  describe('RegisterValidators', function () {
    it('Should revert if directly called without access', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await expect(nodeManager.registerValidator(owner.address, pubkey1)).to.be.revertedWith(
        'Only node operator can register validators!',
      );
    });

    it('Should register validators successfully', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await nodeManager.registerNodeOperator();
      const { nodeAddress } = await nodeManager.getNodeOperator(owner.address);
      const nodeOperator = await ethers.getContractAt('IDepositNodeOperator', nodeAddress);
      const validatorCount = 2;
      const minOperatorStakingAmount = await nodeManager.getMinOperatorStakingAmount();
      const pubkeys = pubkey1 + removePrefix(pubkey2);
      const preSignatures = preSignature1 + removePrefix(preSignature2);
      const depositSignatures = depositSignature1 + removePrefix(depositSignature2);
      await expect(
        nodeOperator.addValidators(pubkeys, preSignatures, depositSignatures, {
          value: minOperatorStakingAmount.mul(validatorCount),
        }),
      )
        .to.emit(nodeManager, 'SigningKeyAdded')
        .withArgs(0, owner.address, pubkey1)
        .to.emit(nodeManager, 'SigningKeyAdded')
        .withArgs(1, owner.address, pubkey2);
      expect(await nodeManager.getTotalValidatorsCount()).to.equal(validatorCount);
      expect(await nodeManager.getTotalActivatedValidatorsCount()).to.equal(0);
      let nodeValidator = await nodeManager.getNodeValidator(0);
      expect(nodeValidator['operator']).to.equal(owner.address);
      expect(nodeValidator['pubkey']).to.equal(pubkey1);
      expect(nodeValidator['status']).to.equal(1);
      nodeValidator = await nodeManager.getNodeValidator(1);
      expect(nodeValidator['operator']).to.equal(owner.address);
      expect(nodeValidator['pubkey']).to.equal(pubkey2);
      expect(nodeValidator['status']).to.equal(1);
      nodeValidator = await nodeManager.getNodeValidator(2);
      expect(nodeValidator['operator']).to.equal(ethers.constants.AddressZero);
      expect(nodeValidator['pubkey']).to.equal('0x');
      expect(nodeValidator['status']).to.equal(0);
    });

    it('Each should register validators successfully', async function () {
      const { nodeManager, owner, otherAccount } = await loadFixture(deployDepositNodeManager);
      await nodeManager.registerNodeOperator();
      const nodeOperatorReturned = await nodeManager.getNodeOperator(owner.address);
      const nodeOperator = await ethers.getContractAt('IDepositNodeOperator', nodeOperatorReturned['nodeAddress']);
      await nodeManager.connect(otherAccount).registerNodeOperator();
      const nodeOperatorReturned2 = await nodeManager.getNodeOperator(otherAccount.address);
      const nodeOperator2 = await ethers.getContractAt('IDepositNodeOperator', nodeOperatorReturned2['nodeAddress']);
      const minOperatorStakingAmount = await nodeManager.getMinOperatorStakingAmount();
      await expect(
        nodeOperator.addValidators(pubkey1, preSignature1, depositSignature1, { value: minOperatorStakingAmount }),
      )
        .to.emit(nodeManager, 'SigningKeyAdded')
        .withArgs(0, owner.address, pubkey1);
      await expect(
        nodeOperator2
          .connect(otherAccount)
          .addValidators(pubkey2, preSignature2, depositSignature2, { value: minOperatorStakingAmount }),
      )
        .to.emit(nodeManager, 'SigningKeyAdded')
        .withArgs(1, otherAccount.address, pubkey2);
      let nodeValidator = await nodeManager.getNodeValidator(0);
      expect(nodeValidator['operator']).to.equal(owner.address);
      expect(nodeValidator['pubkey']).to.equal(pubkey1);
      expect(nodeValidator['status']).to.equal(1);
      nodeValidator = await nodeManager.getNodeValidator(1);
      expect(nodeValidator['operator']).to.equal(otherAccount.address);
      expect(nodeValidator['pubkey']).to.equal(pubkey2);
      expect(nodeValidator['status']).to.equal(1);
    });
  });

  describe('SetMinOperatorStakingAmount', function () {
    it('Should have default min operator staking amount', async function () {
      const { nodeManager } = await loadFixture(deployDepositNodeManager);
      expect(await nodeManager.getMinOperatorStakingAmount()).to.equal(ethers.utils.parseEther('2'));
    });

    it('Should set min operator staking amount successfully', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      const minAmount = ethers.utils.parseEther('1');
      await expect(nodeManager.setMinOperatorStakingAmount(minAmount))
        .to.emit(nodeManager, 'MinOperatorStakingAmountSet')
        .withArgs(owner.address, ethers.utils.parseEther('2'), minAmount);
      expect(await nodeManager.getMinOperatorStakingAmount()).to.equal(minAmount);
    });

    it('Should revert if called without access', async function () {
      const { nodeManager, otherAccount } = await loadFixture(deployDepositNodeManager);
      const minAmount = ethers.utils.parseEther('1');
      await expect(nodeManager.connect(otherAccount).setMinOperatorStakingAmount(minAmount)).to.be.revertedWith(
        'Account is not a temporary guardian',
      );
    });
  });

  describe('ActivateValidators', function () {
    async function addValidatorsAndDeposit(nodeManager, account, pubkeys, preSignatures, depositSignatures) {
      await nodeManager.connect(account).registerNodeOperator();
      const { nodeAddress } = await nodeManager.getNodeOperator(account.address);
      const nodeOperator = await ethers.getContractAt('IDepositNodeOperator', nodeAddress);
      const validatorCount = 2;
      const minOperatorStakingAmount = await nodeManager.getMinOperatorStakingAmount();
      await nodeOperator.connect(account).addValidators(pubkeys, preSignatures, depositSignatures, {
        value: minOperatorStakingAmount.mul(validatorCount),
      });
      return nodeOperator;
    }

    it('Should activate validators successfully', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await addValidatorsAndDeposit(
        nodeManager,
        owner,
        pubkey1 + removePrefix(pubkey2),
        preSignature1 + removePrefix(preSignature2),
        depositSignature1 + removePrefix(depositSignature2),
      );
      await expect(nodeManager.activateValidators([0, 1]))
        .to.emit(nodeManager, 'SigningKeyActivated')
        .withArgs(0, owner.address, pubkey1)
        .to.emit(nodeManager, 'SigningKeyActivated')
        .withArgs(1, owner.address, pubkey2);
      expect(await nodeManager.getTotalValidatorsCount()).to.equal(2);
      expect(await nodeManager.getTotalActivatedValidatorsCount()).to.equal(2);
      let nodeValidator = await nodeManager.getNodeValidator(0);
      expect(nodeValidator['operator']).to.equal(owner.address);
      expect(nodeValidator['pubkey']).to.equal(pubkey1);
      expect(nodeValidator['status']).to.equal(2);
      nodeValidator = await nodeManager.getNodeValidator(1);
      expect(nodeValidator['operator']).to.equal(owner.address);
      expect(nodeValidator['pubkey']).to.equal(pubkey2);
      expect(nodeValidator['status']).to.equal(2);
      nodeValidator = await nodeManager.getNodeValidator(2);
      expect(nodeValidator['operator']).to.equal(ethers.constants.AddressZero);
      expect(nodeValidator['pubkey']).to.equal('0x');
      expect(nodeValidator['status']).to.equal(0);
    });

    it('Each should activate validators successfully', async function () {
      const { nodeManager, owner, otherAccount } = await loadFixture(deployDepositNodeManager);
      await addValidatorsAndDeposit(nodeManager, owner, pubkey1, preSignature1, depositSignature1);
      await addValidatorsAndDeposit(nodeManager, otherAccount, pubkey2, preSignature2, depositSignature2);
      await expect(nodeManager.activateValidators([0]))
        .to.emit(nodeManager, 'SigningKeyActivated')
        .withArgs(0, owner.address, pubkey1);
      expect(await nodeManager.getTotalActivatedValidatorsCount()).to.equal(1);
      await expect(nodeManager.activateValidators([1]))
        .to.emit(nodeManager, 'SigningKeyActivated')
        .withArgs(1, otherAccount.address, pubkey2);
      expect(await nodeManager.getTotalActivatedValidatorsCount()).to.equal(2);
      let nodeValidator = await nodeManager.getNodeValidator(0);
      expect(nodeValidator['operator']).to.equal(owner.address);
      expect(nodeValidator['pubkey']).to.equal(pubkey1);
      expect(nodeValidator['status']).to.equal(2);
      nodeValidator = await nodeManager.getNodeValidator(1);
      expect(nodeValidator['operator']).to.equal(otherAccount.address);
      expect(nodeValidator['pubkey']).to.equal(pubkey2);
      expect(nodeValidator['status']).to.equal(2);
    });

    it('Should revert if called without access', async function () {
      const { nodeManager, owner, otherAccount } = await loadFixture(deployDepositNodeManager);
      await addValidatorsAndDeposit(nodeManager, owner, pubkey1, preSignature1, depositSignature1);
      await expect(nodeManager.connect(otherAccount).activateValidators([0])).to.be.revertedWith(
        'Account is not a temporary guardian',
      );
    });

    it('Should revert if activate pubkey not exist', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await addValidatorsAndDeposit(nodeManager, owner, pubkey1, preSignature1, depositSignature1);
      await expect(nodeManager.activateValidators([0, 1])).to.be.revertedWith("Validator status isn't waiting activated!");
    });

    it('Should revert if activate pubkey repeatedly', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await addValidatorsAndDeposit(nodeManager, owner, pubkey1, preSignature1, depositSignature1);
      await nodeManager.activateValidators([0]);
      await expect(nodeManager.activateValidators([0])).to.be.revertedWith("Validator status isn't waiting activated!");
    });
  });
});
