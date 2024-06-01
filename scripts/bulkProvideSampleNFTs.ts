import hre, { ethers } from "hardhat";
import { config as dotenvConfig } from "dotenv";
const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
import { resolve } from "path";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });
import config from '../config.json';
import * as _ from 'lodash';

(async () => {
    const nftSymbols = Object.keys(config.NFT);
    for (let i = 0; i < 100; i++) {
        const symbol = _.sample(nftSymbols);
        const [owner] = await hre.ethers.getSigners();
        const contractType = 'IncoNFT';
        const nftAddress = _.get(config, `NFT.${symbol}.address`, '') || '';
        if (!nftAddress) {
            console.error("There is no NFT contract deployed for the symbol: ", symbol);
            process.exit(1);
        }

        const mintTestNFTAddr = config.MintTestNFT;
        const mintTestNFTContractType = 'MintTestNFT';
        const mintTestNFTContract = await ethers.getContractAt(mintTestNFTContractType, mintTestNFTAddr);

        const contract = await ethers.getContractAt(contractType, nftAddress);
        console.log(`Minting NFT ${symbol} to ${owner.address}`);
        try {
            const tx = await contract.connect(owner).mint(owner.address);
            console.log(`Minted NFT ${symbol} to ${owner.address}`);
            await tx.wait();
            const nftBalance = parseInt((await contract.balanceOf(owner.address)).toString());
            if (nftBalance > 0) {
                const tokenId = await contract.tokenOfOwnerByIndex(owner.address, 0);
                console.log(`Providing NFT ${symbol} with tokenId: ${tokenId} to MintTestNFT`)
                const txApproval = await contract.connect(owner).approve(mintTestNFTAddr, tokenId);
                await txApproval.wait();
                console.log(`Approved MintTestNFT`)
                const txProviding = await mintTestNFTContract.connect(owner).addMoreTestNFTs(nftAddress, tokenId);
                await txProviding.wait();
                console.log(`Successful!`);
            } else {
                console.log(`Failed to provide NFT ${symbol}`);
            }
        } catch (e) {
            console.error("Error minting NFT: ", e);
        }
    }
})()