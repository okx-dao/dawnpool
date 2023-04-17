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
    const nodeManager = await DepositNodeManager.attach(nodeManagerAddr)
    const [owner, otherAccount] = await ethers.getSigners();
    return { nodeManager, owner, otherAccount };
  }

  describe('Deployment', function () {
    it('Should deploy succeeded', async function () {
      const { nodeManager } = await loadFixture(deployDepositNodeManager);
      expect(nodeManager.address).to.not.equal('0x0');
    });
  });

  describe('RegisterNodeOperator', function () {
    it('Should deploy a node operator contract', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await nodeManager.registerNodeOperator();
      const { nodeAddress } = await nodeManager.getNodeOperator(owner.address);
      expect(nodeAddress).to.not.equal('0x0');
    });

    it('Should set the new node operator active', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await nodeManager.registerNodeOperator();
      const { isActive } = await nodeManager.getNodeOperator(owner.address);
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

    it('Should have correct node operator contract owner', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
      await nodeManager.registerNodeOperator();
      const { nodeAddress } = await nodeManager.getNodeOperator(owner.address);
      const nodeOperator = await ethers.getContractAt('IDepositNodeOperator', nodeAddress);
      expect(await nodeOperator.getOperator()).to.equal(owner.address);
    });

    it('Should revert if register repeatedly', async function () {
      const { nodeManager, owner } = await loadFixture(deployDepositNodeManager);
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
});
