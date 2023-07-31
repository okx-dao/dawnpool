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
// const { keccak256, encodePacked } = require('web3-utils');

async function main() {
  // npx hardhat run --network goerli  scripts/oracle/exit-deploy.js
  // todo update here
  // const dawnStorageAddr = '0x72EBc6d33Ca025fF478C4820f69dD7Ce34eA0Dc7';
  // const dawnStorageFactory = await ethers.getContractFactory('DawnStorage');
  // const dawnStorage = dawnStorageFactory.attach(dawnStorageAddr);

  // const dawnStorageFactory = await ethers.getContractFactory('DawnStorage');
  // const dawnStorage = await dawnStorageFactory.deploy();

  const validatorsExitBusOracleFactory = await ethers.getContractFactory('ValidatorsExitBusOracle');
  // const validatorsExitBusOracle = await validatorsExitBusOracleFactory.deploy(dawnStorage.address);
  const validatorsExitBusOracle = await validatorsExitBusOracleFactory.attach(
    '0x2Dda54178Fe1969984368f4Bd414176312a52553',
  );
  console.log('deploy validatorsExitBusOracle Contract to:', validatorsExitBusOracle.address);

  //genesisTime goerli:1616508000 mainnet:1606824023 local:1639659600
  // await validatorsExitBusOracle.initialize(10, 32, 12, 1616508000, 0)
  //  await validatorsExitBusOracle.setFrameConfig(10, 10)
  // await validatorsExitBusOracle.addOracleMember("0x4c3aEEE3410B92c30A5B99DDE3CaFe3Eb203A70B")
  // await validatorsExitBusOracle.getLastProcessingRefSlot()

  console.log('getLastProcessingRefSlot: ', await validatorsExitBusOracle.getLastProcessingRefSlot());
  // console.log("getBeaconSpec: ",await validatorsExitBusOracle.getBeaconSpec())

  // await dawnStorage.setAddress(keccak256(encodePacked('contract.address', "ValidatorsExitBusOracle")), validatorsExitBusOracle.address);
  // await dawnStorage.setBool(keccak256(encodePacked('contract.exists', validatorsExitBusOracle.address)), true);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
