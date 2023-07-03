const { ethers, web3 } = require('hardhat');
const { getChainInfo } = require('./deployContracts');

async function deposit() {
  const DepositContract = await ethers.getContractFactory('DepositContract');
  const { chainName, depositContractAddr } = await getChainInfo();
  console.log(`Current chainName: ${chainName}, deposit contract address: ${depositContractAddr}`);
  const depositContract = await DepositContract.attach(depositContractAddr);
  const tx = await depositContract.deposit('0x957f3a659faa3cdcd21be00a05b7bbca25a41b2f2384166ca5872363c37110b3dedbab1261179338fadc4ff70b4bea57',
    '0x010000000000000000000000123463a4b065722e99115d6c222f267d9cabb524',
    '0xa0ca81e596cde0774db463914164d87a5c2bf99bc78aad86402350cc09f698123eac48c2fec393830f07547cf00ac4bc0507c799d8361740d08677eefb813354364677bbcd5b3a33ea6fd2f66a654270964727bef00a9adcc45dddbbe8f47e51',
    '0x588d5bf4aaabb9f3d886bbdb03b1a5dd94e625680f66ceda9969a606c5cd771c', { value: ethers.utils.parseEther('32')});
  console.log(`Transaction sent, hash: ${tx.hash}, waiting confirmed...`);
  await tx.wait();
  const res = await web3.eth.getTransaction(tx.hash);
  console.log(res);
}

deposit();
