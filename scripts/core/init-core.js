// const { deployContracts } = require('../deployments');
//
// deployContracts()
//   .then(() => process.exit(0))
//   .catch(error => {
//     console.error(error);
//     process.exit(1);
//   });

// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require('hardhat');
const { ethers } = require('hardhat');
const { keccak256, encodePacked } = require('web3-utils');

async function main() {
  // npx hardhat run --network goerli  scripts/core/init-core.js
  const dawnStorageAddr = '0xeDAD3F908Cf4E617905026e6A979502f88E48028';
  const dawnStorageFactory = await ethers.getContractFactory('DawnStorage');
  const dawnStorage = dawnStorageFactory.attach(dawnStorageAddr);

  // core
  const FEE_KEY = keccak256('dawnDeposit.fee');
  const INSURANCE_FEE_KEY = keccak256('dawnDeposit.insuranceFee');
  const TREASURY_FEE_KEY = keccak256('dawnDeposit.treasuryFee');
  const NODE_OPERATOR_FEE_KEY = keccak256('dawnDeposit.nodeOperatorFee');

  await dawnStorage.setUint(FEE_KEY, 1000);
  await dawnStorage.setUint(INSURANCE_FEE_KEY, 5000);
  await dawnStorage.setUint(TREASURY_FEE_KEY, 0);
  await dawnStorage.setUint(NODE_OPERATOR_FEE_KEY, 5000);

  await dawnStorage.setAddress(
    keccak256(encodePacked('contract.address', 'DepositContract')),
    '0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b',
  );

  // oracle
  const dawnPoolOracleFactory = await ethers.getContractFactory('DawnPoolOracle');
  const dawnPoolOracle = await dawnPoolOracleFactory.attach('0x1B38b1D02F4693C4bda78F6d2f38fa1DC0050334');

  await dawnPoolOracle.initialize(10, 32, 12, 1616508000);
  await dawnPoolOracle.addOracleMember('0x4c3aEEE3410B92c30A5B99DDE3CaFe3Eb203A70B');

  const validatorsExitBusOracleFactory = await ethers.getContractFactory('ValidatorsExitBusOracle');
  const validatorsExitBusOracle = await validatorsExitBusOracleFactory.attach(
    '0x09Fadb49E7dCb6dd31F899A9d34eD11dC376F16E',
  );

  await validatorsExitBusOracle.initialize(10, 32, 12, 1616508000, 0);
  await validatorsExitBusOracle.addOracleMember('0x4c3aEEE3410B92c30A5B99DDE3CaFe3Eb203A70B');

  // 初始化 DepositNodeManager 参数
  const depositNodeManagerFactory = await ethers.getContractFactory('DepositNodeManager');
  const depositNodeManager = await depositNodeManagerFactory.attach('0xcC8dE3cC38eE9A0BCAa95F1b1817dCb4eAf71744');
  await depositNodeManager.setMinOperatorStakingAmount(ethers.utils.parseEther('2'));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
