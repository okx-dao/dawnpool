const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');
const { ethers } = require('hardhat');
const { deployContracts, getDeployedContractAddress } = require('../utils/deployContracts');
const { BigNumber } = require('ethers');

describe('DepositNodeOperator', function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployDepositNodeOperator() {
    // Contracts are deployed using the first signer/account by default
    await deployContracts();
    const nodeManagerAddr = await getDeployedContractAddress('DepositNodeManager');
    const DepositNodeManager = await ethers.getContractFactory('DepositNodeManager');
    const nodeManager = await DepositNodeManager.attach(nodeManagerAddr);
    const [owner, otherAccount] = await ethers.getSigners();
    await nodeManager.registerNodeOperator(owner.address);
    const { nodeAddress } = await nodeManager.getNodeOperator(owner.address);
    const nodeOperator = await ethers.getContractAt('DepositNodeOperator', nodeAddress);
    const dawnDepositAddr = await getDeployedContractAddress('DawnDeposit');
    const DawnDeposit = await ethers.getContractFactory('DawnDeposit');
    const dawnDeposit = await DawnDeposit.attach(dawnDepositAddr);
    dawnDeposit.stake({ value: ethers.utils.parseEther('60') });
    return { nodeOperator, nodeManager, owner, otherAccount };
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
  const pubkeyLen = 48;
  const signatureLen = 96;

  function removePrefix(str) {
    return str.substring(2);
  }

  describe('Deployment', function () {
    it('Should deploy succeeded', async function () {
      const { nodeOperator } = await loadFixture(deployDepositNodeOperator);
      expect(nodeOperator.address).to.not.equal(ethers.constants.AddressZero);
    });

    it('Should have correct node operator contract owner', async function () {
      const { nodeOperator, owner } = await loadFixture(deployDepositNodeOperator);
      expect(await nodeOperator.getOperator()).to.equal(owner.address);
    });

    it('Each should have correct node operator contract owner', async function () {
      const { nodeOperator, nodeManager, owner, otherAccount } = await loadFixture(deployDepositNodeOperator);
      await nodeManager.connect(otherAccount).registerNodeOperator(otherAccount.address);
      const { nodeAddress } = await nodeManager.getNodeOperator(otherAccount.address);
      const nodeOperator2 = await ethers.getContractAt('IDepositNodeOperator', nodeAddress);
      expect(await nodeOperator.getOperator()).to.equal(owner.address);
      expect(await nodeOperator2.getOperator()).to.equal(otherAccount.address);
    });
  });

  describe('AddStakes', function () {
    it('Should have correct stakes', async function () {
      const { nodeOperator, otherAccount } = await loadFixture(deployDepositNodeOperator);
      const ethAmount = ethers.utils.parseEther('1');
      await nodeOperator.addStakes({ value: ethAmount });
      const dawnDepositAddr = await getDeployedContractAddress('DawnDeposit');
      const pethERC20 = await ethers.getContractAt('IERC20', dawnDepositAddr);
      const dawnDeposit = await ethers.getContractAt('DawnDeposit', dawnDepositAddr);
      let pethAmount = await pethERC20.balanceOf(nodeOperator.address);
      expect(await dawnDeposit.getEtherByPEth(pethAmount)).to.equal(ethAmount);
      await nodeOperator.connect(otherAccount).addStakes({ value: ethAmount });
      pethAmount = await pethERC20.balanceOf(nodeOperator.address);
      expect(await dawnDeposit.getEtherByPEth(pethAmount)).to.equal(ethAmount.mul(2));
    });
  });

  describe('AddValidators', function () {
    it('Should add validators successfully', async function () {
      const { nodeOperator, nodeManager } = await loadFixture(deployDepositNodeOperator);
      const minOperatorStakingAmount = await nodeManager.getMinOperatorStakingAmount();
      const pubkeys = pubkey1 + removePrefix(pubkey2);
      const preSignatures = preSignature1 + removePrefix(preSignature2);
      const depositSignatures = depositSignature1 + removePrefix(depositSignature2);
      await expect(
        nodeOperator.addValidators(pubkeys, preSignatures, depositSignatures, {
          value: BigNumber.from(minOperatorStakingAmount).mul(2),
        }),
      );
      expect(await nodeOperator.getValidatingValidatorsCount()).to.equal(0);
      const dawnDepositAddr = await getDeployedContractAddress('DawnDeposit');
      const pethERC20 = await ethers.getContractAt('IERC20', dawnDepositAddr);
      const pethAmount = await pethERC20.balanceOf(nodeOperator.address);
      const dawnDeposit = await ethers.getContractAt('DawnDeposit', dawnDepositAddr);
      expect(await dawnDeposit.getEtherByPEth(pethAmount)).to.equal(BigNumber.from(minOperatorStakingAmount).mul(2));
    });

    it('Each should add validators successfully', async function () {
      const { nodeOperator, nodeManager, otherAccount } = await loadFixture(deployDepositNodeOperator);
      await nodeManager.connect(otherAccount).registerNodeOperator(otherAccount.address);
      const { nodeAddress } = await nodeManager.getNodeOperator(otherAccount.address);
      const nodeOperator2 = await ethers.getContractAt('IDepositNodeOperator', nodeAddress);
      const minOperatorStakingAmount = await nodeManager.getMinOperatorStakingAmount();
      await expect(
        nodeOperator.addValidators(pubkey1, preSignature1, depositSignature1, { value: minOperatorStakingAmount }),
      );
      await expect(
        nodeOperator2
          .connect(otherAccount)
          .addValidators(pubkey2, preSignature2, depositSignature2, { value: minOperatorStakingAmount }),
      );
      expect(await nodeOperator.getActiveValidatorsCount()).to.equal(1);
      expect(await nodeOperator.getValidatingValidatorsCount()).to.equal(0);
      expect(await nodeOperator2.getActiveValidatorsCount()).to.equal(1);
      expect(await nodeOperator2.getValidatingValidatorsCount()).to.equal(0);
    });

    it('Should revert if public keys length is not correct', async function () {
      const { nodeOperator, nodeManager } = await loadFixture(deployDepositNodeOperator);
      const minOperatorStakingAmount = await nodeManager.getMinOperatorStakingAmount();
      await expect(
        nodeOperator.addValidators(pubkey1.substring(0, 20), preSignature1, depositSignature1, {
          value: minOperatorStakingAmount,
        }),
      ).to.be.revertedWithCustomError(nodeOperator, 'IncorrectPubkeysSignaturesLen')
        .withArgs(9, signatureLen, signatureLen);
    });

    it('Should revert if signatures len is not correct', async function () {
      const { nodeOperator, nodeManager } = await loadFixture(deployDepositNodeOperator);
      const minOperatorStakingAmount = await nodeManager.getMinOperatorStakingAmount();
      await expect(
        nodeOperator.addValidators(pubkey1, preSignature1.substring(0, 40), depositSignature1.substring(0, 40), {
          value: minOperatorStakingAmount,
        }),
      ).to.be.revertedWithCustomError(nodeOperator, 'IncorrectPubkeysSignaturesLen')
        .withArgs(pubkeyLen, 19, 19);
    });

    it('Should revert if deposit signatures len is not correct', async function () {
      const { nodeOperator, nodeManager } = await loadFixture(deployDepositNodeOperator);
      const minOperatorStakingAmount = await nodeManager.getMinOperatorStakingAmount();
      await expect(
        nodeOperator.addValidators(pubkey1, preSignature1, depositSignature1.substring(0, 40), {
          value: minOperatorStakingAmount,
        }),
      ).to.be.revertedWithCustomError(nodeOperator, 'IncorrectPubkeysSignaturesLen')
        .withArgs(pubkeyLen, signatureLen, 19);
    });

    it('Should revert if public keys and signatures length is not inconsistent', async function () {
      const { nodeOperator, nodeManager } = await loadFixture(deployDepositNodeOperator);
      const minOperatorStakingAmount = await nodeManager.getMinOperatorStakingAmount();
      await expect(
        nodeOperator.addValidators(pubkey1 + removePrefix(pubkey2), preSignature1, depositSignature1, {
          value: minOperatorStakingAmount,
        }),
      ).to.be.revertedWithCustomError(nodeOperator, 'IncorrectPubkeysSignaturesLen')
        .withArgs(pubkeyLen * 2, signatureLen, signatureLen);
    });

    it('Should revert if any account except operator adds validators', async function () {
      const { nodeOperator, nodeManager, otherAccount } = await loadFixture(deployDepositNodeOperator);
      const minOperatorStakingAmount = await nodeManager.getMinOperatorStakingAmount();
      await expect(
        nodeOperator
          .connect(otherAccount)
          .addValidators(pubkey1, preSignature1, depositSignature1, { value: minOperatorStakingAmount }),
      ).to.be.revertedWithCustomError(nodeOperator, 'OperatorAccessDenied');
    });

    it('Should revert does not have enough stakes', async function () {
      const { nodeOperator } = await loadFixture(deployDepositNodeOperator);
      await expect(nodeOperator.addValidators(pubkey1, preSignature1, depositSignature1)).to.be.revertedWithCustomError(
        nodeOperator,
        'NotEnoughDeposits',
      ).withArgs(ethers.utils.parseEther('2'), 0);
    });
  });

  describe('ActivateValidator', function () {
    async function addValidatorsAndDeposit(nodeOperator, nodeManager) {
      const validatorCount = 2;
      const minOperatorStakingAmount = await nodeManager.getMinOperatorStakingAmount();
      await nodeOperator.addValidators(
        pubkey1 + removePrefix(pubkey2),
        preSignature1 + removePrefix(preSignature2),
        depositSignature1 + removePrefix(depositSignature2),
        { value: minOperatorStakingAmount.mul(validatorCount) },
      );
    }

    it('Should activate validator successfully', async function () {
      const { nodeOperator, nodeManager } = await loadFixture(deployDepositNodeOperator);
      await addValidatorsAndDeposit(nodeOperator, nodeManager);
      await nodeManager.activateValidators([0]);
      expect(await nodeOperator.getActiveValidatorsCount()).to.equal(2);
      expect(await nodeOperator.getValidatingValidatorsCount()).to.equal(1);
      await nodeManager.activateValidators([1]);
      expect(await nodeOperator.getActiveValidatorsCount()).to.equal(2);
      expect(await nodeOperator.getValidatingValidatorsCount()).to.equal(2);
    });

    it('Should revert if directly called without access ', async function () {
      const { nodeOperator, nodeManager } = await loadFixture(deployDepositNodeOperator);
      await addValidatorsAndDeposit(nodeOperator, nodeManager);
      await expect(nodeOperator.activateValidator(0, pubkey1)).to.be.revertedWith('Invalid or outdated contract');
    });
  });
});
