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
const chai = require('chai');

async function main() {
  // npx hardhat run --network goerli  scripts/core/test-core.js
  const dawnStorageAddr = "0xf0718B4182C67Bbb94c0eDe3850cD41a4c44Ab6d";
  const dawnStorageFactory = await ethers.getContractFactory('DawnStorage');
  const dawnStorage = dawnStorageFactory.attach(dawnStorageAddr);

  const dawnDepositFactory = await ethers.getContractFactory('DawnDeposit');
  const dawnDeposit = await dawnDepositFactory.attach('0x9a8E4ae2fAd1f196a80d28bE375D0147FD8e4846');

  const x = await dawnDeposit.getWithdrawalCredentials();
  console.log("WithdrawalCredentials:" , x);

  console.log('0x2bA0f16Ee6C18d5bca0ba140588077C9fF606fbD balance: ', await dawnDeposit.balanceOf('0x2bA0f16Ee6C18d5bca0ba140588077C9fF606fbD'));
  //getTotalPooledEther、getBufferedEther
  console.log('TotalPooledEther', await dawnDeposit.getTotalPooledEther());
  console.log('BufferedEther', await dawnDeposit.getBufferedEther());
  //getEtherByPEth、getPEthByEther
  console.log('PEth : Eth = 1 : ', await dawnDeposit.getEtherByPEth(1));
  console.log('Eth : PEth = 1 : ', await dawnDeposit.getPEthByEther(1));
  //     bytes32 internal constant _PRE_DEPOSIT_VALIDATORS_KEY = keccak256("dawnDeposit.preDepositValidators");
  console.log('pre deposit validators: ', await dawnStorage.getUint(keccak256("dawnDeposit.preDepositValidators")));
  // getBeaconStat
  console.log('BeaconStat: ', await dawnDeposit.getBeaconStat());

  //     bytes32 internal constant _FEE_KEY = keccak256("dawnDeposit.fee");
  //     bytes32 internal constant _INSURANCE_FEE_KEY = keccak256("dawnDeposit.insuranceFee");
  //     bytes32 internal constant _TREASURY_FEE_KEY = keccak256("dawnDeposit.treasuryFee");
  //     bytes32 internal constant _NODE_OPERATOR_FEE_KEY = keccak256("dawnDeposit.nodeOperatorFee");
  console.log('fee: ', await dawnStorage.getUint(keccak256("dawnDeposit.fee")));
  console.log('insurance fee: ', await dawnStorage.getUint(keccak256("dawnDeposit.insuranceFee")));
  console.log('treasury fee: ', await dawnStorage.getUint(keccak256("dawnDeposit.treasuryFee")));
  console.log('node operator fee: ', await dawnStorage.getUint(keccak256("dawnDeposit.nodeOperatorFee")));

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

