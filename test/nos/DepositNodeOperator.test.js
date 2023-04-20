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
    await nodeManager.registerNodeOperator();
    const [owner, otherAccount] = await ethers.getSigners();
    const { nodeAddress } = await nodeManager.getNodeOperator(owner.address);
    const nodeOperator = await ethers.getContractAt('IDepositNodeOperator', nodeAddress);
    return { nodeOperator, nodeManager, owner, otherAccount };
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
      await nodeManager.connect(otherAccount).registerNodeOperator();
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
      const rewardsVaultAddr = await getDeployedContractAddress('RewardsVault');
      expect(await nodeOperator.getWithdrawalCredentials()).to.hexEqual(
        '0x010000000000000000000000'.concat(rewardsVaultAddr.slice(2)),
      );
      const minOperatorStakingAmount = await nodeManager.getMinOperatorStakingAmount();
      const pubkeys =
        '0x957f3a659faa3cdcd21be00a05b7bbca25a41b2f2384166ca5872363c37110b3dedbab1261179338fadc4ff70b4bea57976b8dc5e9390c75d129609634fec912d3d5b2fcb5ef4badb806a68680d11df640cba696619be05896e0705c32db629b';
      const signatures =
        '0xa10eba2dbd2d8c2030b3a13b4cdd52912b324f127ba9b56ed7713d16941245b9d664610ebac541fbd58e64bc1cc598410ccf8795c418ee43d1a4a3842bcbc5fbf45da3abf742e45b98db1e00faebbf8ce477df37496eddf4a00d72905ec71a48a168068916cdc998d6c94816f914aea4b315f47ee65140c16140e989533ed8a73f8730e7a619b0ef4ecb69109bd7401813bcf3386731f8cabd41ea867c8673e2116f0e6d451c026418e565be94c8fa35725fb2cc5d5d6e465da61ceb3f50d6c2';
      const validatorCount = 2;
      await expect(
        nodeOperator.addValidators(pubkeys, signatures, { value: BigNumber.from(minOperatorStakingAmount).mul(2) }),
      )
        .to.emit(nodeOperator, 'SigningKeyAdded')
        .withArgs(
          0,
          '0x957f3a659faa3cdcd21be00a05b7bbca25a41b2f2384166ca5872363c37110b3dedbab1261179338fadc4ff70b4bea57',
        )
        .to.emit(nodeOperator, 'SigningKeyAdded')
        .withArgs(
          1,
          '0x976b8dc5e9390c75d129609634fec912d3d5b2fcb5ef4badb806a68680d11df640cba696619be05896e0705c32db629b',
        );
      expect(await nodeOperator.getActiveValidatorsCount()).to.equal(validatorCount);
      expect(await nodeOperator.getValidatingValidatorsCount()).to.equal(0);
      const dawnDepositAddr = await getDeployedContractAddress('DawnDeposit');
      const pethERC20 = await ethers.getContractAt('IERC20', dawnDepositAddr);
      const pethAmount = await pethERC20.balanceOf(nodeOperator.address);
      const dawnDeposit = await ethers.getContractAt('DawnDeposit', dawnDepositAddr);
      expect(await dawnDeposit.getEtherByPEth(pethAmount)).to.equal(BigNumber.from(minOperatorStakingAmount).mul(2));
    });

    it('Each should add validators successfully', async function () {
      const { nodeOperator, nodeManager, otherAccount } = await loadFixture(deployDepositNodeOperator);
      await nodeManager.connect(otherAccount).registerNodeOperator();
      const { nodeAddress } = await nodeManager.getNodeOperator(otherAccount.address);
      const nodeOperator2 = await ethers.getContractAt('IDepositNodeOperator', nodeAddress);
      const minOperatorStakingAmount = await nodeManager.getMinOperatorStakingAmount();
      const pubkey =
        '0x957f3a659faa3cdcd21be00a05b7bbca25a41b2f2384166ca5872363c37110b3dedbab1261179338fadc4ff70b4bea57';
      const signature =
        '0xa10eba2dbd2d8c2030b3a13b4cdd52912b324f127ba9b56ed7713d16941245b9d664610ebac541fbd58e64bc1cc598410ccf8795c418ee43d1a4a3842bcbc5fbf45da3abf742e45b98db1e00faebbf8ce477df37496eddf4a00d72905ec71a48';
      await expect(nodeOperator.addValidators(pubkey, signature, { value: minOperatorStakingAmount }))
        .to.emit(nodeOperator, 'SigningKeyAdded')
        .withArgs(0, pubkey);
      const pubkey2 =
        '0x976b8dc5e9390c75d129609634fec912d3d5b2fcb5ef4badb806a68680d11df640cba696619be05896e0705c32db629b';
      const signature2 =
        '0xa168068916cdc998d6c94816f914aea4b315f47ee65140c16140e989533ed8a73f8730e7a619b0ef4ecb69109bd7401813bcf3386731f8cabd41ea867c8673e2116f0e6d451c026418e565be94c8fa35725fb2cc5d5d6e465da61ceb3f50d6c2';
      await expect(
        nodeOperator2.connect(otherAccount).addValidators(pubkey2, signature2, { value: minOperatorStakingAmount }),
      )
        .to.emit(nodeOperator2, 'SigningKeyAdded')
        .withArgs(1, pubkey2);
      expect(await nodeOperator.getActiveValidatorsCount()).to.equal(1);
      expect(await nodeOperator.getValidatingValidatorsCount()).to.equal(0);
      expect(await nodeOperator2.getActiveValidatorsCount()).to.equal(1);
      expect(await nodeOperator2.getValidatingValidatorsCount()).to.equal(0);
    });

    it('Should revert if public keys length is not correct', async function () {
      const { nodeOperator, nodeManager } = await loadFixture(deployDepositNodeOperator);
      const pubkey = '0x957f3a659faa3cdcd21be00a05b7bbca';
      const signature =
        '0xa10eba2dbd2d8c2030b3a13b4cdd52912b324f127ba9b56ed7713d16941245b9d664610ebac541fbd58e64bc1cc598410ccf8795c418ee43d1a4a3842bcbc5fbf45da3abf742e45b98db1e00faebbf8ce477df37496eddf4a00d72905ec71a48';
      const minOperatorStakingAmount = await nodeManager.getMinOperatorStakingAmount();
      await expect(
        nodeOperator.addValidators(pubkey, signature, { value: minOperatorStakingAmount }),
      ).to.be.revertedWith('Inconsistent public keys len!');
    });

    it('Should revert if signatures length is not correct', async function () {
      const { nodeOperator, nodeManager } = await loadFixture(deployDepositNodeOperator);
      const pubkey =
        '0x957f3a659faa3cdcd21be00a05b7bbca25a41b2f2384166ca5872363c37110b3dedbab1261179338fadc4ff70b4bea57';
      const signature =
        '0xa10eba2dbd2d8c2030b3a13b4cdd52912b324f127ba9b56ed7713d16941245b9d664610ebac541fbd58e64bc1cc598410ccf8795c418ee43d1a4a3842bcb';
      const minOperatorStakingAmount = await nodeManager.getMinOperatorStakingAmount();
      await expect(
        nodeOperator.addValidators(pubkey, signature, { value: minOperatorStakingAmount }),
      ).to.be.revertedWith('Inconsistent signatures len!');
    });

    it('Should revert if public keys and signatures length is not inconsistent', async function () {
      const { nodeOperator, nodeManager } = await loadFixture(deployDepositNodeOperator);
      const pubkey =
        '0x957f3a659faa3cdcd21be00a05b7bbca25a41b2f2384166ca5872363c37110b3dedbab1261179338fadc4ff70b4bea57';
      const signature =
        '0xa10eba2dbd2d8c2030b3a13b4cdd52912b324f127ba9b56ed7713d16941245b9d664610ebac541fbd58e64bc1cc598410ccf8795c418ee43d1a4a3842bcbc5fbf45da3abf742e45b98db1e00faebbf8ce477df37496eddf4a00d72905ec71a48a168068916cdc998d6c94816f914aea4b315f47ee65140c16140e989533ed8a73f8730e7a619b0ef4ecb69109bd7401813bcf3386731f8cabd41ea867c8673e2116f0e6d451c026418e565be94c8fa35725fb2cc5d5d6e465da61ceb3f50d6c2';
      const minOperatorStakingAmount = await nodeManager.getMinOperatorStakingAmount();
      await expect(
        nodeOperator.addValidators(pubkey, signature, { value: minOperatorStakingAmount }),
      ).to.be.revertedWith('Inconsistent signatures count!');
    });

    it('Should revert if any account except operator adds validators', async function () {
      const { nodeOperator, nodeManager, otherAccount } = await loadFixture(deployDepositNodeOperator);
      const pubkey =
        '0x957f3a659faa3cdcd21be00a05b7bbca25a41b2f2384166ca5872363c37110b3dedbab1261179338fadc4ff70b4bea57';
      const signature =
        '0xa10eba2dbd2d8c2030b3a13b4cdd52912b324f127ba9b56ed7713d16941245b9d664610ebac541fbd58e64bc1cc598410ccf8795c418ee43d1a4a3842bcbc5fbf45da3abf742e45b98db1e00faebbf8ce477df37496eddf4a00d72905ec71a48';
      const minOperatorStakingAmount = await nodeManager.getMinOperatorStakingAmount();
      await expect(
        nodeOperator.connect(otherAccount).addValidators(pubkey, signature, { value: minOperatorStakingAmount }),
      ).to.be.revertedWith('Only operator can add validators!');
    });

    it('Should revert does not have enough stakes', async function () {
      const { nodeOperator } = await loadFixture(deployDepositNodeOperator);
      const pubkey =
        '0x957f3a659faa3cdcd21be00a05b7bbca25a41b2f2384166ca5872363c37110b3dedbab1261179338fadc4ff70b4bea57';
      const signature =
        '0xa10eba2dbd2d8c2030b3a13b4cdd52912b324f127ba9b56ed7713d16941245b9d664610ebac541fbd58e64bc1cc598410ccf8795c418ee43d1a4a3842bcbc5fbf45da3abf742e45b98db1e00faebbf8ce477df37496eddf4a00d72905ec71a48';
      await expect(nodeOperator.addValidators(pubkey, signature)).to.be.revertedWith('Not enough deposits!');
    });
  });
});
