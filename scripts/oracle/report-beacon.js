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
// const { BigNumber } = require('ethers');

async function main() {
  // npx hardhat run --network goerli  scripts/oracle/report-beacon.js
  const dawnPoolOracleFactory = await ethers.getContractFactory('DawnPoolOracle');
  const dawnPoolOracleOracle = await dawnPoolOracleFactory.attach('0x1B38b1D02F4693C4bda78F6d2f38fa1DC0050334');

  const frameFirstEpochId = await dawnPoolOracleOracle.getFrameFirstEpochId();
  console.log('frameFirstEpochId= ', frameFirstEpochId);
  // (190220, 0, 0, 64001989366000000000, 2 , 11978844447443412188, 1, 9958588402895866439)
  const report_data = {
    epochId: 190240,
    beaconBalance: 0,
    beaconValidators: 0,
    rewardsVaultBalance: '64001989366000000000',
    exitedValidators: 2,
    burnedPEthAmount: '11978844447443412188',
    lastRequestIdToBeFulfilled: 1,
    ethAmountToLock: '9958588402895866439',
  };

  const result = await dawnPoolOracleOracle.reportBeacon(report_data);
  console.log('result= ', result);
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
