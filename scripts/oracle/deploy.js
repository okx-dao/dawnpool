// const { deployContracts } = require('../deployments');
//
// deployContracts()
//   .then(() => process.exit(0))
//   .catch(error => {
//     console.error(error);
//     process.exit(1);
//   });

// const hre = require('hardhat');
const { ethers } = require('hardhat');
const { keccak256, encodePacked } = require('web3-utils');

async function main() {
  // npx hardhat run --network goerli  scripts/oracle/deploy.js
  // todo update here
  const dawnStorageAddr = '0xf0718B4182C67Bbb94c0eDe3850cD41a4c44Ab6d';
  const dawnStorageFactory = await ethers.getContractFactory('DawnStorage');
  const dawnStorage = dawnStorageFactory.attach(dawnStorageAddr);

  // const dawnStorageFactory = await ethers.getContractFactory('DawnStorage');
  // const dawnStorage = await dawnStorageFactory.deploy();

  const dawnPoolOracleFactory = await ethers.getContractFactory('DawnPoolOracle');
  const dawnPoolOracle = await dawnPoolOracleFactory.deploy(dawnStorage.address);
  console.log('deploy dawnPoolOracle Contract to:', dawnPoolOracle.address);

  //genesisTime goerli:1616508000 mainnet:1606824023 local:1639659600
  await dawnPoolOracle.initialize(225, 32, 12, 1616508000);
  await dawnPoolOracle.addOracleMember('0x4c3aEEE3410B92c30A5B99DDE3CaFe3Eb203A70B');

  console.log('getBeaconSpec: ', await dawnPoolOracle.getBeaconSpec());

  await dawnStorage.setAddress(keccak256(encodePacked('contract.address', 'DawnPoolOracle')), dawnPoolOracle.address);
  await dawnStorage.setBool(keccak256(encodePacked('contract.exists', dawnPoolOracle.address)), true);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
