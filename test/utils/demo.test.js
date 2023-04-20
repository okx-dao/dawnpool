const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { ethers } = require('hardhat');
const chai = require('chai');
const Web3 = require('web3');
const RPC_ENDPOINT = 'http://localhost:8545';

const { send, ether } = require('@openzeppelin/test-helpers');
describe('DawnDemoTest', function () {
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

  describe('stakeWeb3DemoTest', function () {
    const provider = new Web3.providers.HttpProvider(RPC_ENDPOINT);
    const web3 = new Web3(provider);
    it('Should stake success', async function () {
      const { dawnDeposit, owner } = await loadFixture(deployDawnDepositFixture);

      await web3.eth.sendTransaction({
        from: owner.address,
        to: dawnDeposit.address,
        value: web3.utils.toWei('10', 'ether'),
      });
      // stake 0
      try {
        await dawnDeposit.stake({ from: owner.address, value: 0 });
      } catch (e) {
        console.log('stake 0');
        chai.assert.match(e, /STAKE_ZERO_ETHER/);
      }

      // stake 1
      await dawnDeposit.stake({ from: owner.address, value: 1 });
      await chai.assert.equal(await dawnDeposit.balanceOf(owner.address), 1);
    });
  });

  describe('stakeHelpersDemoTest', function () {
    it('Should stake success', async function () {
      const { dawnDeposit, owner } = await loadFixture(deployDawnDepositFixture);

      await send.ether(owner.address, dawnDeposit.address, ether('10'));
      // stake 0
      try {
        await dawnDeposit.stake({ from: owner.address, value: 0 });
      } catch (e) {
        console.log('stake 0');
        chai.assert.match(e, /STAKE_ZERO_ETHER/);
      }

      // stake 1
      await dawnDeposit.stake({ from: owner.address, value: 1 });
      await chai.assert.equal(await dawnDeposit.balanceOf(owner.address), 1);
    });
  });
});
