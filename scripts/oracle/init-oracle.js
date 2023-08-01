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
  // npx hardhat run --network goerli  scripts/core/init-oracle.js
  const dawnStorageAddr = '0xf0718B4182C67Bbb94c0eDe3850cD41a4c44Ab6d';
  const dawnStorageFactory = await ethers.getContractFactory('DawnStorage');
  const dawnStorage = dawnStorageFactory.attach(dawnStorageAddr);

  const dawnPoolOracleFactory = await ethers.getContractFactory('DawnPoolOracle');
  const dawnPoolOracle = await dawnPoolOracleFactory.attach('0x47ed8d4bCE7e180116Ee263c8CAC0C103172F5d8');

  await dawnPoolOracle.initialize(225, 32, 12, 1616508000);
  await dawnPoolOracle.addOracleMember('0x4c3aEEE3410B92c30A5B99DDE3CaFe3Eb203A70B');

  await dawnStorage.setAddress(keccak256(encodePacked('contract.address', 'DawnPoolOracle')), dawnPoolOracle.address);
  await dawnStorage.setBool(keccak256(encodePacked('contract.exists', dawnPoolOracle.address)), true);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
