const { ethers } = require('hardhat');
// const { BN } = require('bn.js');
const chai = require('chai');
const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { keccak256, encodePacked } = require('web3-utils');
const { expect } = require('chai');

// const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

describe('DawnDepositTest', function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployDawnDepositFixture() {
    // Contracts are deployed using the first signer/account by default

    const [owner, otherAccount] = await ethers.getSigners();

    const DawnStorage = await ethers.getContractFactory('DawnStorage');
    const ds = await DawnStorage.deploy();
    console.log('deployDawnStorage Contract deployed to:', ds.address);

    const dawnDepositFactory = await ethers.getContractFactory('DawnDeposit');
    const dawnDeposit = await dawnDepositFactory.deploy(ds.address);
    console.log('deploy DawnDeposit Contract deployed to:', dawnDeposit.address);

    const dawnInsuranceFactory = await ethers.getContractFactory('DawnInsurance');
    const dawnInsurance = await dawnInsuranceFactory.deploy(ds.address);
    console.log('deploy dawnInsurance Contract to:', dawnInsurance.address);

    const dawnTreasuryFactory = await ethers.getContractFactory('DawnTreasury');
    const dawnTreasury = await dawnTreasuryFactory.deploy(ds.address);
    console.log('deploy dawnTreasury Contract to:', dawnTreasury.address);

    const rewardsVaultFactory = await ethers.getContractFactory('RewardsVault');
    const rewardsVault = await rewardsVaultFactory.deploy(ds.address);
    console.log('deploy rewardsVault Contract to:', rewardsVault.address);

    await ds.setAddress(keccak256(encodePacked('contract.address', 'RewardsVault')), rewardsVault.address);
    await ds.setBool(keccak256(encodePacked('contract.exists', rewardsVault.address)), true);

    await ds.setAddress(keccak256(encodePacked('contract.address', 'DawnDeposit')), dawnDeposit.address);
    await ds.setBool(keccak256(encodePacked('contract.exists', dawnDeposit.address)), true);

    await ds.setAddress(keccak256(encodePacked('contract.address', 'DawnPoolOracle')), owner.address);
    await ds.setBool(keccak256(encodePacked('contract.exists', owner.address)), true);

    await ds.setAddress(keccak256(encodePacked('contract.address', 'DawnInsurance')), dawnInsurance.address);
    await ds.setBool(keccak256(encodePacked('contract.exists', dawnInsurance.address)), true);

    await ds.setAddress(keccak256(encodePacked('contract.address', 'DawnTreasury')), dawnTreasury.address);
    await ds.setBool(keccak256(encodePacked('contract.exists', dawnTreasury.address)), true);

    return { dawnDeposit, owner, otherAccount };
  }

  describe('handleOracleReport', function () {
    it('Should handle success', async function () {
      const { dawnDeposit } = await loadFixture(deployDawnDepositFixture);

      // await dawnDeposit.stake({ from: owner.address, value: 1 });
      // await chai.assert.equal(await dawnDeposit.balanceOf(owner.address), 1);

      await expect(dawnDeposit.handleOracleReport(0, 0, 0, 0, 0)).to.be.revertedWith('unprofitable');
      // await dawnDeposit.handleOracleReport(0, 0, '33000000000000000000', 0, 0)

      console.log(await dawnDeposit.getWithdrawalCredentials());
      //
      // await dawnDeposit.stake({ from: owner.address, value: 1 });
      // await chai.assert.equal(await dawnDeposit.balanceOf(owner.address), 1);

      console.log(await dawnDeposit.getBufferedEther());
      console.log(await dawnDeposit.getTotalPooledEther());
      console.log(await dawnDeposit.getBeaconStat());
    });
  });

  describe('stakeTest', function () {
    it('Should stake success', async function () {
      const { dawnDeposit, owner } = await loadFixture(deployDawnDepositFixture);

      // stake 0
      try {
        await dawnDeposit.stake({ from: owner.address, value: 0 });
      } catch (e) {
        chai.assert.match(e, /STAKE_ZERO_ETHER/);
      }

      // try {
      //     await web3.eth.sendTransaction({ to: dawnDeposit.address, from: owner.address, value: 0 })
      // } catch (e) {
      //     chai.assert.match(e, /STAKE_ZERO_ETHER/)
      //     console.log(e)
      // }

      // stake 1
      await dawnDeposit.stake({ from: owner.address, value: 1 });
      await chai.assert.equal(await dawnDeposit.balanceOf(owner.address), 1);

      // await web3.eth.sendTransaction({ to: dawnDeposit.address, from: owner.address, value: 1 })
      // await chai.assert.equal(await dawnDeposit.balanceOf(owner.address), 2)
    });
  });

  // describe("")
});
