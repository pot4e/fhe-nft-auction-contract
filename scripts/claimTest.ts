import hre, { ethers } from "hardhat";
import { config as dotenvConfig } from "dotenv";
const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
import { resolve } from "path";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });
import config from '../config.json';
import * as _ from 'lodash';
import { createInstances } from "../test/instance";
import { getSigners } from "../test/signers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

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
    const erc20TokenAddress = await contract.paymentToken();
    const contractERC20 = await ethers.getContractAt('EncryptedERC20', erc20TokenAddress, wallet1);
    console.log(`Contract ${contractType} at ${mintTestNFTAddr} with payment token ${erc20TokenAddress}`);
    const instancesERC20 = await createInstances(erc20TokenAddress, ethers, await getSigners(ethers));
    const token = instancesERC20.account1.getTokenSignature(erc20TokenAddress) || {
        signature: "",
        publicKey: "",
    };
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
            const balance = instancesERC20.account1.decrypt(erc20TokenAddress, await contractERC20.balanceOf(token.publicKey, token.signature));
            console.log(`Balance of ${wallet1.address} before Claim`, balance.toString());

            const txTransfer = await contract.connect(wallet1).claimTestToken();
            await txTransfer.wait();
            console.log(`Claimed EncryptedToken to ${wallet1.address} with tx: ${txTransfer.hash}`);

            const balance1 = instancesERC20.account1.decrypt(erc20TokenAddress, await contractERC20.balanceOf(token.publicKey, token.signature));
            console.log(`Balance of ${wallet1.address} After Claim`, balance1.toString());
        } catch (e) {
            console.error("Error claiming EncryptedToken: ", e);
        }
    }
})()