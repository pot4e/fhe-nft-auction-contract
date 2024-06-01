import hre, { ethers } from "hardhat";
import { config as dotenvConfig } from "dotenv";
const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
import { resolve } from "path";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });
import config from '../config.json';
import * as _ from 'lodash';
import { createInstances } from "../test/instance";
import { getSigners } from "../test/signers";

(async () => {
    const [owner] = await hre.ethers.getSigners();
    const contractType = 'EncryptedERC20';
    const tokenAddress = config.ERC20;
    if (!tokenAddress) {
        console.error("There is no tokenAddress contract deployed");
        process.exit(1);
    }
    const recipient = config.MintTestNFT;
    const contract = await ethers.getContractAt(contractType, tokenAddress, owner);
    console.log(`Minting Token to ${recipient}`);
    try {
        const instances = await createInstances(tokenAddress, ethers, await getSigners(ethers));
        const encryptedAmount = instances.owner.encrypt32(Number(10_000_000));
        const tx = await contract.mint(encryptedAmount);
        await tx.wait();
        const txTransfer1 = await contract["transfer(address,bytes)"](recipient, encryptedAmount);
        await txTransfer1.wait();
        console.log(`Transfer 10m tokens to ${recipient}`, txTransfer1.hash);
        console.log(`Minted 10_000_000 tokens to ${owner.address}`);
    } catch (e) {
        console.error("Error minting NFT: ", e);
    }
})()