const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { anyValue } = require('@nomicfoundation/hardhat-chai-matchers/withArgs');
const { expect } = require('chai');
const { ethers } = require('hardhat');
const { deployContracts, getDeployedContractAddress } = require('../utils/deployContracts');
const { depositBufferedEther, setValidatorUnsafe } = require('../utils/makeSecurityModuleSignature');

const ValidatorStatus = {
  NOT_EXIST: 0,
  WAITING_ACTIVATED: 1,
  VALIDATING: 2,
  EXIT: 3,
  SLASHING: 4,
  //        EXITED,
  UNSAFE: 5,
};

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
    const depositSecurityModuleAddress = await getDeployedContractAddress('DawnDepositSecurityModule');
    const DawnDepositSecurityModule = await ethers.getContractFactory('DawnDepositSecurityModule');
    const depositSecurityModule = await DawnDepositSecurityModule.attach(depositSecurityModuleAddress);
    return { nodeManager, depositSecurityModule, owner, otherAccount };
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
      await nodeManager.registerNodeOperator(owner.address);
      const { nodeAddress, isActive } = await nodeManager.getNodeOperator(owner.address);
      expect(nodeAddress).to.not.equal(ethers.constants.AddressZero);
      expect(isActive).to.equal(true);
      expect(await nodeManager.getWithdrawAddress(owner.address)).to.equal(owner.address);
    });

    it('Should deploy node operator contract to different addresses', async function () {
      const { nodeManager, owner, otherAccount } = await loadFixture(deployDepositNodeManager);
      await nodeManager.registerNodeOperator(owner.address);
      const { nodeAddress } = await nodeManager.getNodeOperator(owner.address);
      await nodeManager.connect(otherAccount).registerNodeOperator(otherAccount.address);
      const { nodeAddress2 } = await nodeManager.getNodeOperator(otherAccount.address);
      expect(nodeAddress).to.not.equal(nodeAddress2);
      expect(await nodeManager.getWithdrawAddress(owner.address)).to.equal(owner.address);
      expect(await nodeManager.getWithdrawAddress(otherAccount.address)).to.equal(otherAccount.address);
    });

    it('Should revert if register repeatedly', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await nodeManager.registerNodeOperator(owner.address);
      await expect(nodeManager.registerNodeOperator(owner.address)).to.be.revertedWithCustomError(
        nodeManager,
        'OperatorAlreadyExist',
      );
    });

    it('Should emit events when register node operator', async function () {
      const { nodeManager, owner, otherAccount } = await loadFixture(deployDepositNodeManager);
      await expect(nodeManager.registerNodeOperator(owner.address))
        .to.emit(nodeManager, 'NodeOperatorRegistered')
        .withArgs(owner.address, anyValue)
        .to.emit(nodeManager, 'WithdrawAddressSet')
        .withArgs(owner.address, owner.address);
      await expect(nodeManager.connect(otherAccount).registerNodeOperator(otherAccount.address))
        .to.emit(nodeManager, 'NodeOperatorRegistered')
        .withArgs(otherAccount.address, anyValue)
        .to.emit(nodeManager, 'WithdrawAddressSet')
        .withArgs(otherAccount.address, otherAccount.address);
    });

    it('Should revert if withdraw address is 0x', async function () {
      const { nodeManager } = await loadFixture(deployDepositNodeManager);
      await expect(nodeManager.registerNodeOperator(ethers.constants.AddressZero)).to.be.revertedWithCustomError(
        nodeManager,
        'ZeroAddress',
      );
    });
  });

  describe('SetWithdrawAddress', function () {
    it('Should set withdraw address successfully', async function () {
      const { nodeManager, owner, otherAccount } = await loadFixture(deployDepositNodeManager);
      await expect(nodeManager.registerNodeOperator(owner.address));
      await expect(nodeManager.connect(otherAccount).registerNodeOperator(otherAccount.address));
      expect(await nodeManager.getWithdrawAddress(owner.address)).to.equal(owner.address);
      expect(await nodeManager.getWithdrawAddress(otherAccount.address)).to.equal(otherAccount.address);
      await expect(nodeManager.setWithdrawAddress(otherAccount.address))
        .to.emit(nodeManager, 'WithdrawAddressSet')
        .withArgs(owner.address, otherAccount.address);
      await expect(nodeManager.connect(otherAccount).setWithdrawAddress(owner.address))
        .to.emit(nodeManager, 'WithdrawAddressSet')
        .withArgs(otherAccount.address, owner.address);
      expect(await nodeManager.getWithdrawAddress(owner.address)).to.equal(otherAccount.address);
      expect(await nodeManager.getWithdrawAddress(otherAccount.address)).to.equal(owner.address);
    });

    it('Should revert if operator not exist', async function () {
      const { nodeManager, owner, otherAccount } = await loadFixture(deployDepositNodeManager);
      await expect(nodeManager.registerNodeOperator(owner.address));
      await expect(nodeManager.setWithdrawAddress(otherAccount.address))
        .to.emit(nodeManager, 'WithdrawAddressSet')
        .withArgs(owner.address, otherAccount.address);
      expect(await nodeManager.getWithdrawAddress(owner.address)).to.equal(otherAccount.address);
      await expect(
        nodeManager.connect(otherAccount).setWithdrawAddress(otherAccount.address),
      ).to.be.revertedWithCustomError(nodeManager, 'NotExistOperator');
    });

    it('Should revert if withdraw address is 0x', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await expect(nodeManager.registerNodeOperator(owner.address));
      await expect(nodeManager.setWithdrawAddress(ethers.constants.AddressZero)).to.be.revertedWithCustomError(
        nodeManager,
        'ZeroAddress',
      );
    });
  });

  describe('RegisterValidator', function () {
    it('Should revert if directly called without access', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await expect(nodeManager.registerValidator(owner.address, pubkey1))
        .to.be.revertedWithCustomError(nodeManager, 'InconsistentNodeOperatorAddress')
        .withArgs(owner.address, ethers.constants.AddressZero, owner.address);
    });

    it('Should register validators successfully', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await nodeManager.registerNodeOperator(owner.address);
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
      let nodeValidator = await nodeManager['getNodeValidator(uint256)'](0);
      expect(nodeValidator['operator']).to.equal(owner.address);
      expect(nodeValidator['pubkey']).to.equal(pubkey1);
      expect(nodeValidator['status']).to.equal(ValidatorStatus.WAITING_ACTIVATED);
      nodeValidator = await nodeManager['getNodeValidator(uint256)'](1);
      expect(nodeValidator['operator']).to.equal(owner.address);
      expect(nodeValidator['pubkey']).to.equal(pubkey2);
      expect(nodeValidator['status']).to.equal(ValidatorStatus.WAITING_ACTIVATED);
      nodeValidator = await nodeManager['getNodeValidator(uint256)'](2);
      expect(nodeValidator['operator']).to.equal(ethers.constants.AddressZero);
      expect(nodeValidator['pubkey']).to.equal('0x');
      expect(nodeValidator['status']).to.equal(ValidatorStatus.NOT_EXIST);
    });

    it('Each should register validators successfully', async function () {
      const { nodeManager, owner, otherAccount } = await loadFixture(deployDepositNodeManager);
      await nodeManager.registerNodeOperator(owner.address);
      const nodeOperatorReturned = await nodeManager.getNodeOperator(owner.address);
      const nodeOperator = await ethers.getContractAt('IDepositNodeOperator', nodeOperatorReturned['nodeAddress']);
      await nodeManager.connect(otherAccount).registerNodeOperator(owner.address);
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
      let nodeValidator = await nodeManager['getNodeValidator(uint256)'](0);
      expect(nodeValidator['operator']).to.equal(owner.address);
      expect(nodeValidator['pubkey']).to.equal(pubkey1);
      expect(nodeValidator['status']).to.equal(ValidatorStatus.WAITING_ACTIVATED);
      nodeValidator = await nodeManager['getNodeValidator(uint256)'](1);
      expect(nodeValidator['operator']).to.equal(otherAccount.address);
      expect(nodeValidator['pubkey']).to.equal(pubkey2);
      expect(nodeValidator['status']).to.equal(ValidatorStatus.WAITING_ACTIVATED);
    });

    it('Should revert if one pubkey registered repeatedly', async function () {
      const { nodeManager, owner, otherAccount } = await loadFixture(deployDepositNodeManager);
      await nodeManager.registerNodeOperator(owner.address);
      const nodeOperatorReturned = await nodeManager.getNodeOperator(owner.address);
      const nodeOperator = await ethers.getContractAt('IDepositNodeOperator', nodeOperatorReturned['nodeAddress']);
      await nodeManager.connect(otherAccount).registerNodeOperator(owner.address);
      const minOperatorStakingAmount = await nodeManager.getMinOperatorStakingAmount();
      await expect(
        nodeOperator.addValidators(pubkey1, preSignature1, depositSignature1, { value: minOperatorStakingAmount }),
      )
        .to.emit(nodeManager, 'SigningKeyAdded')
        .withArgs(0, owner.address, pubkey1);
      await expect(
        nodeOperator.addValidators(pubkey1, preSignature1, depositSignature1, { value: minOperatorStakingAmount }),
      ).to.be.revertedWithCustomError(nodeManager, 'PubkeyAlreadyExist');
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
        .withArgs(owner.address, minAmount);
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
      await expect(depositBufferedEther([0, 1]))
        .to.emit(nodeManager, 'SigningKeyActivated')
        .withArgs(0, owner.address, pubkey1)
        .to.emit(nodeManager, 'SigningKeyActivated')
        .withArgs(1, owner.address, pubkey2);
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

    it('Each should activate validators successfully', async function () {
      const { nodeManager, owner, otherAccount } = await loadFixture(deployDepositNodeManager);
      await addValidatorsAndDeposit(nodeManager, owner, pubkey1, preSignature1, depositSignature1);
      await addValidatorsAndDeposit(nodeManager, otherAccount, pubkey2, preSignature2, depositSignature2);
      await expect(depositBufferedEther([0]))
        .to.emit(nodeManager, 'SigningKeyActivated')
        .withArgs(0, owner.address, pubkey1);
      expect(await nodeManager.getTotalActivatedValidatorsCount()).to.equal(1);
      await expect(depositBufferedEther([1]))
        .to.emit(nodeManager, 'SigningKeyActivated')
        .withArgs(1, otherAccount.address, pubkey2);
      expect(await nodeManager.getTotalActivatedValidatorsCount()).to.equal(2);
      let nodeValidator = await nodeManager['getNodeValidator(uint256)'](0);
      expect(nodeValidator['operator']).to.equal(owner.address);
      expect(nodeValidator['pubkey']).to.equal(pubkey1);
      expect(nodeValidator['status']).to.equal(ValidatorStatus.VALIDATING);
      nodeValidator = await nodeManager['getNodeValidator(uint256)'](1);
      expect(nodeValidator['operator']).to.equal(otherAccount.address);
      expect(nodeValidator['pubkey']).to.equal(pubkey2);
      expect(nodeValidator['status']).to.equal(ValidatorStatus.VALIDATING);
    });

    it('Should revert if called without access', async function () {
      const { nodeManager, owner, otherAccount } = await loadFixture(deployDepositNodeManager);
      await addValidatorsAndDeposit(nodeManager, owner, pubkey1, preSignature1, depositSignature1);
      await expect(nodeManager.connect(otherAccount).activateValidators([0])).to.be.revertedWith(
        'Invalid or outdated contract',
      );
    });

    it('Should revert if activate pubkey not exist', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await addValidatorsAndDeposit(nodeManager, owner, pubkey1, preSignature1, depositSignature1);
      await expect(depositBufferedEther([0, 1])).to.be.reverted;
    });

    it('Should revert if activate pubkey repeatedly', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await addValidatorsAndDeposit(nodeManager, owner, pubkey1, preSignature1, depositSignature1);
      await depositBufferedEther([0]);
      await expect(depositBufferedEther([0])).to.be.reverted;
    });
  });

  async function activateValidators(nodeManager, owner) {
    await addValidatorsAndDeposit(
      nodeManager,
      owner,
      pubkey1 + removePrefix(pubkey2),
      preSignature1 + removePrefix(preSignature2),
      depositSignature1 + removePrefix(depositSignature2),
    );
    await depositBufferedEther([0, 1]);
  }

  describe('ValidatorsStatusChange', function () {
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

    it('Should set validator exit successfully', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await activateValidators(nodeManager, owner);
      expect(await nodeManager.getTotalActivatedValidatorsCount()).to.equal(2);
      await expect(nodeManager.setValidatorExit(0))
        .to.emit(nodeManager, 'SigningKeyExit')
        .withArgs(0, owner.address, pubkey1);
      const { index, operator, status } = await nodeManager['getNodeValidator(bytes)'](pubkey1);
      expect(index).to.equal(0);
      expect(operator).to.equal(owner.address);
      expect(status).to.equal(ValidatorStatus.EXIT);
      expect(await nodeManager.getTotalActivatedValidatorsCount()).to.equal(1);
      await expect(nodeManager.setValidatorExit(0))
        .to.be.revertedWithCustomError(nodeManager, 'InconsistentValidatorStatus')
        .withArgs(0, ValidatorStatus.VALIDATING, ValidatorStatus.EXIT);
      expect((await nodeManager.getNodeOperator(owner.address)).isActive).to.equal(true);
    });

    it('Should set validator slashing successfully', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await activateValidators(nodeManager, owner);
      expect(await nodeManager.getTotalActivatedValidatorsCount()).to.equal(2);
      const { nodeAddress, isActive } = await nodeManager.getNodeOperator(owner.address);
      expect(isActive).to.equal(true);
      const dawnDepositAddr = await getDeployedContractAddress('DawnDeposit');
      const dawnDeposit = await ethers.getContractAt('DawnDeposit', dawnDepositAddr);
      const pethAmount = await dawnDeposit.getPEthByEther(ethers.utils.parseEther('1'));
      await expect(nodeManager.setValidatorSlashing(0, pethAmount, false))
        .to.emit(nodeManager, 'SigningKeySlashing')
        .withArgs(0, owner.address, pubkey1, nodeAddress, pethAmount)
        .to.emit(nodeManager, 'NodeOperatorActiveStatusChanged')
        .withArgs(owner.address, false);
      expect((await nodeManager.getNodeOperator(owner.address)).isActive).to.equal(false);
      const { index, operator, status } = await nodeManager['getNodeValidator(bytes)'](pubkey1);
      expect(index).to.equal(0);
      expect(operator).to.equal(owner.address);
      expect(status).to.equal(ValidatorStatus.SLASHING);
      expect(await nodeManager.getTotalActivatedValidatorsCount()).to.equal(1);
      await expect(nodeManager.setValidatorSlashing(0, pethAmount, false))
        .to.be.revertedWithCustomError(nodeManager, 'InconsistentValidatorStatus')
        .withArgs(0, ValidatorStatus.VALIDATING, ValidatorStatus.SLASHING);
    });

    it('Should set validator slashing finished successfully', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await activateValidators(nodeManager, owner);
      expect(await nodeManager.getTotalActivatedValidatorsCount()).to.equal(2);
      const { nodeAddress } = await nodeManager.getNodeOperator(owner.address);
      const dawnDepositAddr = await getDeployedContractAddress('DawnDeposit');
      const dawnDeposit = await ethers.getContractAt('DawnDeposit', dawnDepositAddr);
      const pethAmount = await dawnDeposit.getPEthByEther(ethers.utils.parseEther('1'));
      await expect(nodeManager.setValidatorSlashing(0, pethAmount, true))
        .to.be.revertedWithCustomError(nodeManager, 'InconsistentValidatorStatus')
        .withArgs(0, ValidatorStatus.SLASHING, ValidatorStatus.VALIDATING);
      await nodeManager.setValidatorSlashing(0, pethAmount, false);
      await expect(nodeManager.setValidatorSlashing(0, pethAmount, true))
        .to.emit(nodeManager, 'SigningKeySlashing')
        .withArgs(0, owner.address, pubkey1, nodeAddress, pethAmount)
        .to.emit(nodeManager, 'SigningKeyExit')
        .withArgs(0, owner.address, pubkey1);
      expect((await nodeManager.getNodeOperator(owner.address)).isActive).to.equal(false);
      const { index, operator, status } = await nodeManager['getNodeValidator(bytes)'](pubkey1);
      expect(index).to.equal(0);
      expect(operator).to.equal(owner.address);
      expect(status).to.equal(ValidatorStatus.EXIT);
      expect(await nodeManager.getTotalActivatedValidatorsCount()).to.equal(1);
      await expect(nodeManager.setValidatorSlashing(0, pethAmount, true))
        .to.be.revertedWithCustomError(nodeManager, 'InconsistentValidatorStatus')
        .withArgs(0, ValidatorStatus.SLASHING, ValidatorStatus.EXIT);
    });

    it('Should decrease validator shares successfully', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await activateValidators(nodeManager, owner);
      expect(await nodeManager.getTotalActivatedValidatorsCount()).to.equal(2);
      const { nodeAddress } = await nodeManager.getNodeOperator(owner.address);
      const dawnDepositAddr = await getDeployedContractAddress('DawnDeposit');
      const dawnDeposit = await ethers.getContractAt('DawnDeposit', dawnDepositAddr);
      const pethAmount = await dawnDeposit.getPEthByEther(ethers.utils.parseEther('1'));
      await expect(nodeManager.punishOneValidator(0, pethAmount, Buffer.from('test')))
        .to.emit(nodeManager, 'SigningKeyPunished')
        .withArgs(0, owner.address, pubkey1, nodeAddress, pethAmount, Buffer.from('test'));
      expect((await nodeManager.getNodeOperator(owner.address)).isActive).to.equal(true);
    });
  });

  describe('Request to exit validators', function () {
    it('Should revert if called directly without access', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await activateValidators(nodeManager, owner);
      expect(await nodeManager.getTotalActivatedValidatorsCount()).to.equal(2);
      const { nodeAddress } = await nodeManager.getNodeOperator(owner.address);
      await expect(nodeManager.operatorRequestToExitValidators(owner.address, [0, 1]))
        .to.be.revertedWithCustomError(nodeManager, 'InconsistentNodeOperatorAddress')
        .withArgs(owner.address, nodeAddress, owner.address);
    });

    it('Should request to exit successfully', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await activateValidators(nodeManager, owner);
      expect(await nodeManager.getTotalActivatedValidatorsCount()).to.equal(2);
      const { nodeAddress } = await nodeManager.getNodeOperator(owner.address);
      const nodeOperator = await ethers.getContractAt('DepositNodeOperator', nodeAddress);
      await expect(nodeOperator.voluntaryExitValidators([0, 1]))
        .to.emit(nodeManager, 'SigningKeyExit')
        .withArgs(0, owner.address, pubkey1)
        .to.emit(nodeManager, 'SigningKeyExit')
        .withArgs(1, owner.address, pubkey2);
      expect(await nodeManager.getTotalActivatedValidatorsCount()).to.equal(0);
    });

    it('Should revert if called repeatedly', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await activateValidators(nodeManager, owner);
      const { nodeAddress } = await nodeManager.getNodeOperator(owner.address);
      const nodeOperator = await ethers.getContractAt('DepositNodeOperator', nodeAddress);
      await expect(nodeOperator.voluntaryExitValidators([0]))
        .to.emit(nodeManager, 'SigningKeyExit')
        .withArgs(0, owner.address, pubkey1);
      await expect(nodeOperator.voluntaryExitValidators([0]))
        .to.be.revertedWithCustomError(nodeManager, 'InconsistentValidatorStatus')
        .withArgs(0, ValidatorStatus.VALIDATING, ValidatorStatus.EXIT);
      expect(await nodeManager.getTotalActivatedValidatorsCount()).to.equal(1);
    });

    it('Should revert if request to exit not exist validator', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await activateValidators(nodeManager, owner);
      const { nodeAddress } = await nodeManager.getNodeOperator(owner.address);
      const nodeOperator = await ethers.getContractAt('DepositNodeOperator', nodeAddress);
      await expect(nodeOperator.voluntaryExitValidators([0, 1, 2]))
        .to.be.revertedWithCustomError(nodeManager, 'InconsistentValidatorOperator')
        .withArgs(2, ethers.constants.AddressZero, owner.address);
    });

    it('Should revert if request to exit not owner validator', async function () {
      const { nodeManager, owner, otherAccount } = await loadFixture(deployDepositNodeManager);
      await addValidatorsAndDeposit(nodeManager, owner, pubkey1, preSignature1, depositSignature1);
      await addValidatorsAndDeposit(nodeManager, otherAccount, pubkey2, preSignature2, depositSignature2);
      await depositBufferedEther([0, 1]);
      const { nodeAddress } = await nodeManager.getNodeOperator(owner.address);
      const nodeOperator = await ethers.getContractAt('DepositNodeOperator', nodeAddress);
      await expect(nodeOperator.voluntaryExitValidators([0, 1]))
        .to.be.revertedWithCustomError(nodeManager, 'InconsistentValidatorOperator')
        .withArgs(1, otherAccount.address, owner.address);
    });
  });
});
