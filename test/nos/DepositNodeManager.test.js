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
    return { nodeManager, owner, otherAccount };
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
      await expect(nodeManager.registerValidators(owner.address, 1)).to.be.revertedWith(
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
      const pubkeys =
        '0x957f3a659faa3cdcd21be00a05b7bbca25a41b2f2384166ca5872363c37110b3dedbab1261179338fadc4ff70b4bea57976b8dc5e9390c75d129609634fec912d3d5b2fcb5ef4badb806a68680d11df640cba696619be05896e0705c32db629b';
      const signatures =
        '0xa10eba2dbd2d8c2030b3a13b4cdd52912b324f127ba9b56ed7713d16941245b9d664610ebac541fbd58e64bc1cc598410ccf8795c418ee43d1a4a3842bcbc5fbf45da3abf742e45b98db1e00faebbf8ce477df37496eddf4a00d72905ec71a48a168068916cdc998d6c94816f914aea4b315f47ee65140c16140e989533ed8a73f8730e7a619b0ef4ecb69109bd7401813bcf3386731f8cabd41ea867c8673e2116f0e6d451c026418e565be94c8fa35725fb2cc5d5d6e465da61ceb3f50d6c2';
      await expect(nodeOperator.addValidators(pubkeys, signatures, { value: minOperatorStakingAmount.mul(validatorCount) }))
        .to.emit(nodeManager, 'NodeValidatorsRegistered')
        .withArgs(nodeAddress, 0, validatorCount);
      expect(await nodeManager.getAvailableValidatorsCount()).to.equal(validatorCount);
      let nodeValidator = await nodeManager.getNodeValidator(0);
      expect(nodeValidator['nodeAddress']).to.equal(nodeAddress);
      expect(nodeValidator['status']).to.equal(1);
      nodeValidator = await nodeManager.getNodeValidator(1);
      expect(nodeValidator['nodeAddress']).to.equal(nodeAddress);
      expect(nodeValidator['status']).to.equal(1);
      nodeValidator = await nodeManager.getNodeValidator(2);
      expect(nodeValidator['nodeAddress']).to.equal(ethers.constants.AddressZero);
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
      const pubkey =
        '0x957f3a659faa3cdcd21be00a05b7bbca25a41b2f2384166ca5872363c37110b3dedbab1261179338fadc4ff70b4bea57';
      const signature =
        '0xa10eba2dbd2d8c2030b3a13b4cdd52912b324f127ba9b56ed7713d16941245b9d664610ebac541fbd58e64bc1cc598410ccf8795c418ee43d1a4a3842bcbc5fbf45da3abf742e45b98db1e00faebbf8ce477df37496eddf4a00d72905ec71a48';
      await nodeOperator.addValidators(pubkey, signature, { value: minOperatorStakingAmount });
      const pubkey2 =
        '0x976b8dc5e9390c75d129609634fec912d3d5b2fcb5ef4badb806a68680d11df640cba696619be05896e0705c32db629b';
      const signature2 =
        '0xa168068916cdc998d6c94816f914aea4b315f47ee65140c16140e989533ed8a73f8730e7a619b0ef4ecb69109bd7401813bcf3386731f8cabd41ea867c8673e2116f0e6d451c026418e565be94c8fa35725fb2cc5d5d6e465da61ceb3f50d6c2';
      await nodeOperator2.connect(otherAccount).addValidators(pubkey2, signature2, { value: minOperatorStakingAmount });
      let nodeValidator = await nodeManager.getNodeValidator(0);
      expect(nodeValidator['nodeAddress']).to.equal(nodeOperatorReturned['nodeAddress']);
      expect(nodeValidator['status']).to.equal(1);
      nodeValidator = await nodeManager.getNodeValidator(1);
      expect(nodeValidator['nodeAddress']).to.equal(nodeOperatorReturned2['nodeAddress']);
      expect(nodeValidator['status']).to.equal(1);
    });
  });

  describe('SetMinOperatorStakingAmount', function () {
    it('Should have default min operator staking amount', async function () {
      const { nodeManager } = await loadFixture(deployDepositNodeManager);
      expect(await nodeManager.getMinOperatorStakingAmount()).to.equal(ethers.utils.parseEther('2'));
    });

    it('Should set min operator staking amount successfully', async function () {
      const { nodeManager } = await loadFixture(deployDepositNodeManager);
      const minAmount = ethers.utils.parseEther('1');
      await nodeManager.setMinOperatorStakingAmount(minAmount)
      expect(await nodeManager.getMinOperatorStakingAmount()).to.equal(minAmount);
    });

    it('Should revert if called without access', async function () {
      const { nodeManager, otherAccount } = await loadFixture(deployDepositNodeManager);
      const minAmount = ethers.utils.parseEther('1');
      await expect(nodeManager.connect(otherAccount).setMinOperatorStakingAmount(minAmount))
        .to.be.revertedWith('Account is not a temporary guardian');
    });
  })
});
