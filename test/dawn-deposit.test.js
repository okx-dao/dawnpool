const { artifacts, contract, ethers, web3 } = require('hardhat');
const { BN } = require('bn.js');
const chai = require('chai');
const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { keccak256, encodePacked } = require('web3-utils');

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

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
    return { dawnDeposit, owner, otherAccount };
  }

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
