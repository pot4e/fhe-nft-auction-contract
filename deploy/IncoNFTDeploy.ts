import hre, { ethers } from "hardhat";
import { config as dotenvConfig } from "dotenv";
const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
import { resolve } from "path";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });
(async () => {
    const [owner] = await hre.ethers.getSigners();

    const contractFactory = await ethers.getContractFactory("IncoNFT");
    const contract = await contractFactory.connect(owner).deploy('Angry Cat', 'AgCNFT', 'https://i.imgur.com/TRJfML7.png');
    await contract.waitForDeployment();
    console.log("Inco NFT sample deployed to: ", await contract.getAddress());
})()