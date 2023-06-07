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

  console.log('user 0x2bA0f16Ee6C18d5bca0ba140588077C9fF606fbD balance: ', await dawnDeposit.balanceOf('0x2bA0f16Ee6C18d5bca0ba140588077C9fF606fbD'));
  //DawnInsurance：0x32a3fD7024B4ed67De1d331091f0075DF0243bDd
  console.log('DawnInsurance balance: ', await dawnDeposit.balanceOf('0x32a3fD7024B4ed67De1d331091f0075DF0243bDd'));
  // DawnTreasury： 0xe00c3897596983A9457B0a5D36059A6Cc210d2BC
  console.log('DawnTreasury balance: ', await dawnDeposit.balanceOf('0xe00c3897596983A9457B0a5D36059A6Cc210d2BC'));
  // DepositNodeManager: 0x1E4f4fd4513dCE5FdD51e7e00c9ea0Ca093986cD
  console.log('DepositNodeManager balance: ', await dawnDeposit.balanceOf('0x1E4f4fd4513dCE5FdD51e7e00c9ea0Ca093986cD'));
  // DepositNodeOperator：0x2acd68AF4211BC82Ca526BE28e2fF3A1cfb424c5
  console.log('DepositNodeOperator balance: ', await dawnDeposit.balanceOf('0x2acd68AF4211BC82Ca526BE28e2fF3A1cfb424c5'));

  //getTotalPooledEther、getBufferedEther
  console.log('TotalPooledEther', await dawnDeposit.getTotalPooledEther());
  console.log('BufferedEther', await dawnDeposit.getBufferedEther());
  //getEtherByPEth、getPEthByEther
  console.log('PEth : Eth = 1994408201304753028 : ', await dawnDeposit.getEtherByPEth('1994408201304753028'));
  console.log('Eth : PEth = 4999999999999999 : ', await dawnDeposit.getPEthByEther(4999999999999999));
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

  //await dawnStorage.setAddress(keccak256(encodePacked('contract.address', 'DepositContract')), '0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b');
  console.log('DepositContract: ', await dawnStorage.getAddress(keccak256(encodePacked('contract.address', 'DepositContract'))));

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

