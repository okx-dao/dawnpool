const { ethers, web3, network} = require("hardhat");
const {loadFixture} = require("@nomicfoundation/hardhat-network-helpers");
const {expect} = require("chai");
const {keccak256} = require("hardhat/internal/util/keccak");
const Web3 = require("web3");
const ethereumjsUtil = require("ethereumjs-util");

describe("DawnStorageTest", function () {
    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.
    async function deployDawnStorageFixture() {
        // Contracts are deployed using the first signer/account by default

        const [owner, otherAccount] = await ethers.getSigners();

        const DawnStorage = await ethers.getContractFactory("DawnStorage");
        const ds = await DawnStorage.deploy();
        console.log("deployDawnStorage Contract deployed to:", ds.address);
        return { ds, owner, otherAccount};
    }

    describe("SetAndGetTest", function () {
        it("Should set the right Data", async function () {
            const { ds, owner } = await loadFixture(deployDawnStorageFixture);
            const dsNameSpace  = 'ds.storage.';
            const ethDepositAddress = '0x00000000219ab540356cBB839Cbe05303d7705Fa';
            const nID = 1;
            console.log("owner address is :" + await owner.getAddress());
            console.log("Guardian address is :" + await ds.getGuardian());

            let encodePackedMessage = Web3.utils.encodePacked(dsNameSpace, 'EOAAddress', nID);
            let hashedMessage = keccak256(ethereumjsUtil.toBuffer(encodePackedMessage));
            await ds.setString(hashedMessage, ethDepositAddress);
            console.log("getString is :" + await ds.getString(hashedMessage));

            await ds.setAddress(hashedMessage, ethDepositAddress);
            console.log("getAddress is :" + await ds.getAddress(hashedMessage));

            console.log("setDeployedStatus is :" + await ds.setDeployedStatus());
            console.log("getDeployedStatus is :" + await ds.getDeployedStatus());
        });
    });
});
