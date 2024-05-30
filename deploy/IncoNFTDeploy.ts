import hre, { ethers } from "hardhat";
import { config as dotenvConfig } from "dotenv";
const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
import { resolve } from "path";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });
import fs from 'fs';
import path from 'path';
import * as _ from 'lodash';
const configPath = path.resolve(__dirname, process.env.CONFIG_PATH || '../config.json');
(async () => {
    const deployInfo = fs.readFileSync(path.resolve(__dirname, '../NFTSamples.json'));
    const deployInfoJson = JSON.parse(deployInfo.toString()) as Array<{ name: string, symbol: string, uri: string }>;
    for (let index = 0; index < deployInfoJson.length; index++) {
        const { name, symbol, uri } = deployInfoJson[index];
        try {
            const [owner] = await hre.ethers.getSigners();
            const contractFactory = await ethers.getContractFactory("IncoNFT");
            console.log("Deploying Inco NFT with name: ", name, " symbol: ", symbol, " uri: ", uri);
            const contract = await contractFactory.connect(owner).deploy(name, symbol, uri);
            await contract.waitForDeployment();
            console.log("Inco NFT sample deployed to: ", await contract.getAddress());
            console.log("Start updating config");
            const config = JSON.parse(fs.readFileSync(configPath).toString());
            _.set(config, `NFT.${symbol}`, {
                address: await contract.getAddress(),
                name: name
            });
            fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
            console.log("Config updated");
            for (let index = 0; index < _.sample([1, 2]); index++) {
                const tokenId1 = await contract.mint("0xde67caf68b7dd990a7a0d2929544e81368b20e7e");
                const tokenId2 = await contract.mint("0xe1e2f280b01cad3c75b225092e8ca37674bc8163");
                console.log("Minted token with id: ", tokenId1.toString(), " and ", tokenId2.toString());
            }
        } catch (e) {
            console.error("Error deploying Inco NFT: ", e);
        }
    }
})()