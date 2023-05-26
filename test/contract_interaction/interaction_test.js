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

    // await expect(dawnDeposit.handleOracleReport(0, 0, 0, 0, 0)).to.be.revertedWith('unprofitable')

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
     const { dawnPoolOracle } = await getDeployedContracts();

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
