import hre, { ethers } from "hardhat";
import { config as dotenvConfig } from "dotenv";
const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
import { resolve } from "path";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });
import config from '../config.json';
import * as _ from 'lodash';

const type = process.env.type;
if (!type) {
    console.error("Please provide a type");
    process.exit(1);
}

(async () => {
    const [owner, wallet1] = await hre.ethers.getSigners();
    const contractType = 'MintTestNFT';
    const mintTestNFTAddr = config.MintTestNFT;
    const contract = await ethers.getContractAt(contractType, mintTestNFTAddr);
    if (type === 'nft') {
        console.log(`Claiming NFT to ${wallet1.address}`);
        try {
            const tx = await contract.connect(wallet1).claimTestNFT();
            await tx.wait();
            console.log(`Claimed NFT to ${wallet1.address} with tx: ${tx.hash}`);
        } catch (e) {
            console.error("Error claiming NFT: ", e);
        }
    } else if (type === 'token') {
        console.log(`Claiming EncryptedToken to ${wallet1.address}`);
        try {
            const tx = await contract.connect(wallet1).claimTestToken();
            await tx.wait();
            console.log(`Claimed EncryptedToken to ${wallet1.address} with tx: ${tx.hash}`);
        } catch (e) {
            console.error("Error claiming EncryptedToken: ", e);
        }
    }
})()