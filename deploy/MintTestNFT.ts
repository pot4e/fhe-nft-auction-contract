import hre, { ethers } from "hardhat";
import { createInstances } from "../test/instance";
import { getSigners } from "../test/signers";
import { updateConfig } from "../scripts/utils";
import fs from 'fs';
import path from "path";
(async () => {
    const [owner, account1, account2] = await hre.ethers.getSigners();
    const mainConfig = JSON.parse(fs.readFileSync(path.join(__dirname, "./../config.json")).toString());
    const testTokenAddr = mainConfig['ERC20'] as string;
    const contractFactory = await ethers.getContractFactory("MintTestNFT");
    const contract = await contractFactory.connect(owner).deploy(testTokenAddr);
    await contract.waitForDeployment();
    const contractAddress = await contract.getAddress();
    console.log("MintTestNFT deployed to: ", await contract.getAddress());
    updateConfig("MintTestNFT", contractAddress);
})()