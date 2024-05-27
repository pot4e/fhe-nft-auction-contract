import hre, { ethers } from "hardhat";
import { config as dotenvConfig } from "dotenv";
const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
import { resolve } from "path";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });
import fs from 'fs';
import path from 'path';
import * as _ from 'lodash';

const symbol = process.env.symbol;
const name = process.env.name;
const uri = process.env.uri;

if (!symbol || !name || !uri) {
    console.error("Please provide a name, symbol and URI for the NFT");
    process.exit(1);
}

(async () => {
    const [owner] = await hre.ethers.getSigners();

    const contractFactory = await ethers.getContractFactory("IncoNFT");
    console.log("Deploying Inco NFT with name: ", name, " symbol: ", symbol, " uri: ", uri);
    try {
        const contract = await contractFactory.connect(owner).deploy(name, symbol, uri);
        await contract.waitForDeployment();
        console.log("Inco NFT sample deployed to: ", await contract.getAddress());
        console.log("Start updating config");
        const configContractPath = path.resolve(__dirname, '../config.json');
        const config = JSON.parse(fs.readFileSync(configContractPath).toString());
        _.set(config, `NFT.${symbol}`, {
            address: await contract.getAddress(),
            name: name
        });
        fs.writeFileSync(configContractPath, JSON.stringify(config, null, 2));
        console.log("Config updated");
    } catch (e) {
        console.error("Error deploying Inco NFT: ", e);
    }
})()