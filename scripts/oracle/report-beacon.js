// const { deployContracts } = require('../deployments');
//
// deployContracts()
//   .then(() => process.exit(0))
//   .catch(error => {
//     console.error(error);
//     process.exit(1);
//   });

const hre = require("hardhat");
const { ethers } = require('hardhat');
const { keccak256, encodePacked } = require('web3-utils');

async function main() {

  // npx hardhat run --network goerli  scripts/oracle/report-beacon.js
  const dawnPoolOracleFactory = await ethers.getContractFactory('DawnPoolOracle');
  const dawnPoolOracleOracle = await dawnPoolOracleFactory.attach('0x47ed8d4bCE7e180116Ee263c8CAC0C103172F5d8');

  const frameFirstEpochId = await dawnPoolOracleOracle.getFrameFirstEpochId()
  console.log("frameFirstEpochId= ",frameFirstEpochId)
  const result = await dawnPoolOracleOracle.reportBeacon(185400, 208000855015000000000/1e9, 2, '14000000000000000000', 0);
  console.log("result= ",result)

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});



