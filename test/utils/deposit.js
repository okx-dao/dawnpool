const { ethers, web3 } = require('hardhat');
const { getChainInfo } = require('./deployContracts');

/*
 * use following command to generate new deposit data
 * 1. download ethdo
 * 2. create wallet
 *   ./ethdo wallet create --wallet privatenet --type hd --wallet-passphrase okcoin-123 --mnemonic "hybrid wisdom mixed like rival that fire enhance cage major increase soap damp monster iron much neck fortune relax tuna sadness control whale announce" --allow-weak-passphrases
 * 3. create account
 *   ./ethdo account create --wallet-passphrase okcoin-123 --passphrase okcoin-123 --allow-weak-passphrases --path m/12381/3600/0/0/0 --account privatenet/0
 *   must update --path and --account param
 * 4. generate deposit data
 * ./ethdo validator depositdata --withdrawaladdress 0x026Cc292d54Fa98F604F79EBa5ee6bCA46479944 --depositvalue 32000000000000000000 --forkversion 0x20000089 --passphrase okcoin-123 --validatoraccount privatenet/0
 * */

const withdrawAddress = '0x010000000000000000000000026cc292d54fa98f604f79eba5ee6bca46479944';
const depositAccounts = [
  {
    pubkey: '0xa6ca4ff42909bdbe2035011f7ec3d35812743ddb8fbc01ff85c5b2df933cb2bbd3011cb7b0a434dd1d4d38250e5edee0',
    signature:
      '0xb662bd126390e9fbd58ef4a049bfdc58445528fdc28fd7c26e036a7ab349bc4e1f41fe58aa1baea7ab1f425e6f8d7d560d97f8e7ea3def32dff63a4a631e7c891477a3180575d9b6691cea892914ca6841ecaeea15fa7d2e797a393ef92e9c14',
    depositDataRoot: '0x5f67be480af055d4d9e332b33fb1baeeaf40f5f76ed17fea7d24149040da7036',
  },
  {
    pubkey: '0x970c14cb68237c9363275312171e4379c9ffd7604e19172283279b81ee8c12833fba93d011e549d8376fbdc1daf004c0',
    signature:
      '0x81717bb8f84381ba5296507de029c4ddd55ea6dbb12d63515812b4df9469dd8f0d46edfc24026270dc9777eed087c8d307ab8222c1f7bc22d2a32b90f81e7f3bd91ab6b6f0085b1c408a776584184b8c13dff32c028db39b381bdf01ba0feae2',
    depositDataRoot: '0xcda18312eb1edbbbcc423c87ea7029d0194ba2aed7d119d29782737e9658629c',
  },
  {
    pubkey: '0xaa09adcca0649579b845ffe294aba5d28f5d3eb17cee5fb06155cb1444f13d21be485d412dbed2bf941e215ae4ce289b',
    signature:
      '0x85ad39e17f399e01a743336b63e649ca729d290d7d48ff812ba784daf508ad0edfe21c55b8afc6a2cf1ee5ad2dc9368611193ced829381cb0c6fde4788d42e3f5feb25b1b153c400a0aff523011afb65fbbf169ac704317406a982cb88ada5bb',
    depositDataRoot: '0xd67345e34eb93366bec178e5e825c665f960c73c46a3e0f4bd52489f11f69e7b',
  },
  {
    pubkey: '0xb72527e9800ffa3cebb793e0b01a0811a6391cff62b23095e9c44468c817f3ffabdae40fc9341e0a0ac7509735f4efea',
    signature:
      '0xa5d9fe540a5d6811ebdce20fa22b4bde61ab23a18bc335fc4c4ffa0062886765df43b71ca800f1124dfb5755ecf73ab20de87efa3a7e458150e87a9e92c339c789e4b3d2d32a0f8350c749ab80a1b45f010915785165f481dea682ef21b73c73',
    depositDataRoot: '0x4572146e14bfa1d88143490f6b9998a4ff285b86921aaccf894f1252162689d1',
  },
  {
    pubkey: '0xb2635ddf33111ab510ca47ebba8fc1c75e748fb932b039db1e59548a350d2bba695952b863208d0ac928b7592e630c1a',
    signature:
      '0x80deed562ebeb8abf31c2df76d460209a4d7b8482a59125d6e926a593bd706d6231c1293bb951e782a1a3d6c918c4ca70cc7b039a241db79d922b1bf781f4cca2179a6498ca41ccb8363f1ed50d1f58ccbcc82399a728afc9cde2c623460d5d0',
    depositDataRoot: '0x88235145c96d80feb6ad2724b860f437428b27a06717b5a0523caa5f9fa01c7b',
  },
];

async function accountDeposit(depositContract, pubkey, signature, depositDataRoot) {
  const tx = await depositContract.deposit(pubkey, withdrawAddress, signature, depositDataRoot, {
    value: ethers.utils.parseEther('32'),
  });
  console.log(`use pubkey ${pubkey} deposit, tx hash: ${tx.hash}, waiting confirmed...`);
  await tx.wait();
  console.log(`tx ${tx} confirmed:`);
  let res = await web3.eth.getTransaction(tx.hash);
  console.log(res);
}

async function deposit() {
  const DepositContract = await ethers.getContractFactory('DepositContract');
  const { chainName, depositContractAddr } = await getChainInfo();
  console.log(`Current chainName: ${chainName}, deposit contract address: ${depositContractAddr}`);
  const depositContract = await DepositContract.attach(depositContractAddr);
  for (const account of depositAccounts) {
    const { pubkey, signature, depositDataRoot } = account;
    await accountDeposit(depositContract, pubkey, signature, depositDataRoot);
  }
}

deposit();
