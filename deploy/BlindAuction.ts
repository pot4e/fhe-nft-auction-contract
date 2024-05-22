import hre, { ethers } from "hardhat";
import { config as dotenvConfig } from "dotenv";
const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
import { resolve } from "path";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });
(async () => {
    const [owner] = await hre.ethers.getSigners();

    const contractFactory = await ethers.getContractFactory("BlindAuction");
    const contract = await contractFactory.connect(owner).deploy(process.env.ERC_20 as string);
    await contract.waitForDeployment();
    console.log("BlindAuction deployed to: ", await contract.getAddress());
})()