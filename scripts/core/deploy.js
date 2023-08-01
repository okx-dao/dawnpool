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
// const hre = require('hardhat');
const { ethers } = require('hardhat');
const { keccak256, encodePacked } = require('web3-utils');

const contractList = [
  'DawnDeposit',
  'DawnWithdraw',
  'Burner',
  'DepositNodeManager',
  'DepositNodeOperatorDeployer',
  'DawnPoolOracle',
  'ValidatorsExitBusOracle',
  'DawnInsurance',
  'RewardsVault',
  // 'DawnDepositSecurityModule'
];

async function main() {
  // npx hardhat run --network goerli  scripts/core/deploy.js
  const dawnStorageFactory = await ethers.getContractFactory('DawnStorage');
  // todo update here
  const dawnStorageAddr = '0xeDAD3F908Cf4E617905026e6A979502f88E48028';
  const dawnStorage = await dawnStorageFactory.attach(dawnStorageAddr);

  // deploy contract
  for (const contractName of contractList) {
    const contractFactory = await ethers.getContractFactory(contractName);
    const contractInstance = await contractFactory.deploy(dawnStorage.address);
    console.log('deploy ', contractName, ' Contract to: ', contractInstance.address);
    //
    await dawnStorage.setAddress(keccak256(encodePacked('contract.address', contractName)), contractInstance.address);
    await dawnStorage.setBool(keccak256(encodePacked('contract.exists', contractInstance.address)), true);
  }

  // deploy DawnTreasury
  // const dawnTreasuryFactory = await ethers.getContractFactory('DawnTreasury');
  // const dawnTreasury = await dawnTreasuryFactory.deploy(dawnStorage.address);
  console.log('deploy dawnTreasury Contract to:', '0xe00c3897596983A9457B0a5D36059A6Cc210d2BC');

  await dawnStorage.setAddress(
    keccak256(encodePacked('contract.address', 'DawnTreasury')),
    '0xe00c3897596983A9457B0a5D36059A6Cc210d2BC',
  );
  await dawnStorage.setBool(
    keccak256(encodePacked('contract.exists', '0xe00c3897596983A9457B0a5D36059A6Cc210d2BC')),
    true,
  );

  // deploy DawnDepositSecurityModule
  const dawnDepositSecurityModuleFactory = await ethers.getContractFactory('DawnDepositSecurityModule');
  const dawnDepositSecurityModule = await dawnDepositSecurityModuleFactory.deploy(
    dawnStorage.address,
    '0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b',
  );
  console.log('deploy DawnDepositSecurityModule Contract to: ', dawnDepositSecurityModule.address);
  //
  await dawnStorage.setAddress(
    keccak256(encodePacked('contract.address', 'DawnDepositSecurityModule')),
    dawnDepositSecurityModule.address,
  );
  await dawnStorage.setBool(keccak256(encodePacked('contract.exists', dawnDepositSecurityModule.address)), true);

  // log
  console.log(await dawnStorage.getAddress(keccak256(encodePacked('contract.address', 'DawnDeposit'))));
  console.log(await dawnStorage.getAddress(keccak256(encodePacked('contract.address', 'RewardsVault'))));
  console.log(await dawnStorage.getAddress(keccak256(encodePacked('contract.address', 'DawnInsurance'))));
  console.log(await dawnStorage.getAddress(keccak256(encodePacked('contract.address', 'DawnTreasury'))));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
