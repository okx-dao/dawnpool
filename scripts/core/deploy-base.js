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
  // npx hardhat run --network goerli  scripts/core/deploy-base.js
  // todo update here
  const dawnStorageFactory = await ethers.getContractFactory('DawnStorage');
  const dawnStorage = await dawnStorageFactory.deploy();
  console.log('deploy DawnStorage Contract to:', dawnStorage.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
