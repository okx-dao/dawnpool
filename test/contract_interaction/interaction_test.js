const {
  registerNodeOperatorIfNotRegistered,
  addValidators,
  activateValidators,
  claimRewards,
} = require('./node_operator');
const { expect } = require('chai');
const { ethers } = require('hardhat');
const { anyValue } = require('@nomicfoundation/hardhat-chai-matchers/withArgs');
const { BigNumber } = require('ethers');
const { getDeployedContracts } = require('./dawn_storage');
const chai = require('chai');

describe('InteractionTest', function () {
  const pubkey1 = '0x957f3a659faa3cdcd21be00a05b7bbca25a41b2f2384166ca5872363c37110b3dedbab1261179338fadc4ff70b4bea57';
  const preSignature1 =
    '0x8b6c4138b8f6c8e4811b43b54a9f62dd948a360f3cffd47306c23c2c384f884015a248e335d9f705af6bc14be25d9afd14695ad0bdfa03d0a8176387cddc84c296f17d743841a5f6670c536924f75a7d6248687cdfc01da06e0a6b7eed451d57';
  const depositSignature1 =
    '0x8bdbf12f759142e3b2ae8454407df65ed401aea530cd48dc62ee51c79bb2b4dc414cf733eef8efba7786488d00c1caaa12d8d6a077c3e5f76789074e5d0d86bbb796e1011d37eb5fdd87a3f90392b9484b9aaacb211832582bd776c31b279b45';
  const pubkey2 = '0x976b8dc5e9390c75d129609634fec912d3d5b2fcb5ef4badb806a68680d11df640cba696619be05896e0705c32db629b';
  const preSignature2 =
    '0xaa8d5f134cc1f28667097825d3d02b9d6d922644bc84a5463dcab20b7543f1be4e744ce6e0f821389fb36c7ae7bea4ad184c9b9d979098b3c376b6c31fbbf09ab9292ba04b334bf49fe436c8656545d62bcf882f30427070a548dca203cf43f1';
  const depositSignature2 =
    '0x8d3ef084a582006e042451e8ca6d8d8e4b06761d8b12493cadd0dc3eb9f4f92104536420c095f4a46db3635837fc3e7702d7d40cf27e41b1c97d35ea58e4dae76e3a816f9ccfd0a38ff0e139646fc7e39e575b4bd8e458e98fd548daa39296de';

  function removePrefix(str) {
    return str.substring(2);
  }

  // Step 1: user stake TODO
  it('User stake', async function () {
    const owner = await ethers.getSigner();
    const { dawnDeposit } = await getDeployedContracts();
    // test stake 0
    await expect(dawnDeposit.stake({ from: owner.address, value: 0 })).to.be.revertedWith('STAKE_ZERO_ETHER');

    // test stake > 0 （peth : eth = 1 : 1）
    await dawnDeposit.stake({ value: ethers.utils.parseEther('60') });
    await chai.assert.equal(await dawnDeposit.balanceOf(owner.address), ethers.utils.parseEther('60').toString());
    //getTotalPooledEther、getBufferedEther
    await chai.assert.equal(await dawnDeposit.getTotalPooledEther(), ethers.utils.parseEther('60').toString());
    await chai.assert.equal(await dawnDeposit.getBufferedEther(), ethers.utils.parseEther('60').toString());
    //getEtherByPEth、getPEthByEther
    await chai.assert.equal(await dawnDeposit.getEtherByPEth(1), 1);
    await chai.assert.equal(await dawnDeposit.getPEthByEther(1), 1);
  });

  // Step 2: Node operator stake
  it('Should register node operator succeeded', async function () {
    const { nodeManager, tx } = await registerNodeOperatorIfNotRegistered();
    const owner = await ethers.getSigner();
    if (tx && tx.length > 0) {
      (await expect(tx)).to
        .emit(nodeManager, 'NodeOperatorRegistered')
        .withArgs(owner.address, anyValue)
        .to.emit(nodeManager, 'WithdrawAddressSet')
        .withArgs(owner.address, owner.address);
    }
    const { nodeAddress, isActive } = await nodeManager.getNodeOperator(owner.address);
    expect(nodeAddress).to.not.equal(ethers.constants.AddressZero);
    expect(isActive).to.equal(true);
    expect(await nodeManager.getWithdrawAddress(owner.address)).to.equal(owner.address);
  });

  // Step 3: Node operator add pubkeys
  it('Should add validators succeeded', async function () {
    const { nodeManager, tx } = await addValidators(
      pubkey1 + removePrefix(pubkey2),
      preSignature1 + removePrefix(preSignature2),
      depositSignature1 + removePrefix(depositSignature2),
    );
    const nextValidatorId = await nodeManager.getTotalValidatorsCount();
    const owner = await ethers.getSigner();
    (await expect(tx)).to
      .emit(nodeManager, 'SigningKeyAdded')
      .withArgs(nextValidatorId, owner.address, pubkey1)
      .to.emit(nodeManager, 'SigningKeyAdded')
      .withArgs(nextValidatorId.add(1), owner.address, pubkey2);
  });

  // Step 4: Activate validators
  it('Should activate validators succeeded', async function () {
    const { nodeManager, tx } = await activateValidators([0, 1]);
    const owner = await ethers.getSigner();
    (await expect(tx)).to
      .emit(nodeManager, 'SigningKeyActivated')
      .withArgs(0, owner.address, pubkey1)
      .to.emit(nodeManager, 'SigningKeyActivated')
      .withArgs(1, owner.address, pubkey2);
  });

  // Step 4: Handle oracle report TODO
  it('Handle oracle report', async function () {
    // const [owner, oracleMember, otherAccount] = await ethers.getSigners();
    const { dawnPoolOracle } = await getDeployedContracts();

    const epochId = await dawnPoolOracle.getFrameFirstEpochId();
    //(epochId, beaconBalance, beaconValidators, rewardsVaultBalance, exitedValidators)
    // 无收益
    await expect(dawnPoolOracle.reportBeacon(epochId, 0, 0, 0, 0)).to.be.revertedWith('unprofitable');
    // 奖励库余额不够
    await expect(dawnPoolOracle.reportBeacon(epochId, 0, 0, 1, 0)).to.be.revertedWith(
      'RewardsVault insufficient balance',
    );
    await dawnPoolOracle.reportBeacon(epochId, ethers.utils.parseEther('10'), 0, 0, 0);
  });

  // Step 5: Claim rewards
  it('Should claim rewards succeeded', async function () {
    const { nodeManager, nodeOperator, dawnDeposit, claimableRewards, tx } = await claimRewards();
    const pethERC20 = await ethers.getContractAt('IERC20', dawnDeposit.address);
    const owner = await ethers.getSigner();
    const withdrawAddress = await nodeManager.getWithdrawAddress(owner.address);
    const balanceBefore = await pethERC20.balanceOf(nodeOperator.address);
    const activeValidators = await nodeOperator.getActiveValidatorsCount();
    const minStakingAmount = (await nodeManager.getMinOperatorStakingAmount()).mul(activeValidators);
    const requiredBalance = await dawnDeposit.getPEthByEther(minStakingAmount);
    const stakingRewards = balanceBefore.gt(requiredBalance) ? balanceBefore.sub(requiredBalance) : BigNumber.from(0);
    const nodeRewards = claimableRewards.sub(stakingRewards);
    if (stakingRewards.gt(0) && nodeRewards.gt(0)) {
      (await expect(tx)).to
        .emit(nodeOperator, 'NodeOperatorStakingRewardsClaimed')
        .withArgs(owner.address, withdrawAddress, stakingRewards)
        .to.emit(nodeManager, 'NodeOperatorNodeRewardsClaimed')
        .withArgs(owner.address, nodeOperator.address, withdrawAddress, nodeRewards);
    } else if (nodeRewards.gt(0)) {
      (await expect(tx)).to
        .emit(nodeManager, 'NodeOperatorNodeRewardsClaimed')
        .withArgs(owner.address, nodeOperator.address, withdrawAddress, nodeRewards);
    } else if (stakingRewards.gt(0)) {
      (await expect(tx)).to
        .emit(nodeOperator, 'NodeOperatorStakingRewardsClaimed')
        .withArgs(owner.address, withdrawAddress, stakingRewards);
    } else {
      console.error('No rewards to claim!');
    }
  });
});
