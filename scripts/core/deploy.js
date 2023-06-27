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
  // npx hardhat run --network goerli  scripts/core/deploy.js
  // todo update here
  const dawnStorageAddr = "0x000";
  const dawnStorageFactory = await ethers.getContractFactory('DawnStorage');
  const dawnStorage = dawnStorageFactory.attach(dawnStorageAddr);


  // deploy DawnDeposit
  const dawnDepositFactory = await ethers.getContractFactory('DawnDeposit');
  const dawnDeposit = await dawnDepositFactory.deploy(dawnStorage.address);
  console.log('deploy dawnDeposit Contract to:', dawnDeposit.address)

  await dawnStorage.setAddress(keccak256(encodePacked('contract.address', "DawnDeposit")), dawnDeposit.address);
  await dawnStorage.setBool(keccak256(encodePacked('contract.exists', dawnDeposit.address)), true);


  // deploy RewardsVault
  const rewardsVaultFactory = await ethers.getContractFactory('RewardsVault');
  const rewardsVault = await rewardsVaultFactory.deploy(dawnStorage.address);
  console.log('deploy rewardsVault Contract to:', rewardsVault.address)

  await dawnStorage.setAddress(keccak256(encodePacked('contract.address', "RewardsVault")), rewardsVault.address);
  await dawnStorage.setBool(keccak256(encodePacked('contract.exists', rewardsVault.address)), true);


  // deploy DawnInsurance
  const dawnInsuranceFactory = await ethers.getContractFactory('DawnInsurance');
  const dawnInsurance = await dawnInsuranceFactory.deploy(dawnStorage.address);
  console.log('deploy dawnInsurance Contract to:', dawnInsurance.address)

  await dawnStorage.setAddress(keccak256(encodePacked('contract.address', "DawnInsurance")), dawnInsurance.address);
  await dawnStorage.setBool(keccak256(encodePacked('contract.exists', dawnInsurance.address)), true);


  // deploy DawnTreasury
  // const dawnTreasuryFactory = await ethers.getContractFactory('DawnTreasury');
  // const dawnTreasury = await dawnTreasuryFactory.deploy(dawnStorage.address);
  console.log('deploy dawnTreasury Contract to:', '0xe00c3897596983A9457B0a5D36059A6Cc210d2BC')

  await dawnStorage.setAddress(keccak256(encodePacked('contract.address', "DawnTreasury")), '0xe00c3897596983A9457B0a5D36059A6Cc210d2BC');
  await dawnStorage.setBool(keccak256(encodePacked('contract.exists', '0xe00c3897596983A9457B0a5D36059A6Cc210d2BC')), true);


  // log
  console.log(await dawnStorage.getAddress(keccak256(encodePacked('contract.address', "DawnDeposit"))));
  console.log(await dawnStorage.getAddress(keccak256(encodePacked('contract.address', "RewardsVault"))));
  console.log(await dawnStorage.getAddress(keccak256(encodePacked('contract.address', "DawnInsurance"))));
  console.log(await dawnStorage.getAddress(keccak256(encodePacked('contract.address', "DawnTreasury"))));

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

