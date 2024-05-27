import hre, { ethers } from "hardhat";
import { config as dotenvConfig } from "dotenv";
const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
import { resolve } from "path";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });
import config from '../config.json';
import * as _ from 'lodash';

const symbol = process.env.symbol;
const recipient = process.env.recipient;
if (!symbol || !recipient) {
    console.error("Please provide a name and symbol for the NFT");
    process.exit(1);
}

(async () => {
    const [owner] = await hre.ethers.getSigners();
    const contractType = 'IncoNFT';
    const nftAddress = _.get(config, `NFT.${symbol}.address`, '') || '';
    if (!nftAddress) {
        console.error("There is no NFT contract deployed for the symbol: ", symbol);
        process.exit(1);
    }
    const contract = await ethers.getContractAt(contractType, nftAddress);
    console.log(`Minting NFT ${symbol} to ${recipient}`);
    try {
        const tx = await contract.connect(owner).mint(recipient);
        console.log(`Minted NFT ${symbol} to ${recipient} with tx: ${tx.hash}`);
    } catch (e) {
        console.error("Error minting NFT: ", e);
    }
})()