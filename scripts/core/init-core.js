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
const hre = require("hardhat");
const { ethers } = require('hardhat');
const { keccak256, encodePacked } = require('web3-utils');

async function main() {
  // npx hardhat run --network goerli  scripts/core/init-core.js
  const dawnStorageAddr = "0xf0718B4182C67Bbb94c0eDe3850cD41a4c44Ab6d";
  const dawnStorageFactory = await ethers.getContractFactory('DawnStorage');
  const dawnStorage = dawnStorageFactory.attach(dawnStorageAddr);


  const FEE_KEY = keccak256("dawnDeposit.fee");
  const INSURANCE_FEE_KEY = keccak256("dawnDeposit.insuranceFee");
  const TREASURY_FEE_KEY = keccak256("dawnDeposit.treasuryFee");
  const NODE_OPERATOR_FEE_KEY = keccak256("dawnDeposit.nodeOperatorFee");

  await dawnStorage.setUint(FEE_KEY, 1000);
  await dawnStorage.setUint(INSURANCE_FEE_KEY, 5000);
  await dawnStorage.setUint(TREASURY_FEE_KEY, 0);
  await dawnStorage.setUint(NODE_OPERATOR_FEE_KEY, 5000);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

