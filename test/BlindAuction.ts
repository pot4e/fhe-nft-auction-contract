import { expect } from "chai";
import { ethers } from "hardhat";
import { deployBlindAuctionFixture } from "./BlindAuction.fixture";
import { getSigners } from "./signers";
import { createInstances } from "./instance";
import abiERC721 from "./erc721Abi.json";
import abiERC20 from "./erc20Abi.json";
import { EncryptedERC20 } from "../types";
export const BLIND_TIME = 24 * 60 * 60 * 1000
import { config as dotenvConfig } from "dotenv";
const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
import { resolve } from "path";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

describe("BlindAuction", function () {
  before(async function () {
    this.signers = await getSigners(ethers);
    const contract = await deployBlindAuctionFixture();
    this.contractAddress = await contract.getAddress();
    this.blindAuctionContract = contract
    this.instances = await createInstances(this.contractAddress, ethers, this.signers);
  });
  it("Should set the right contract owner", async function () {
    expect(await this.blindAuctionContract.owner()).to.equal(this.signers.owner.address);
  });

  // it("Should post a NFT to bid", async function () {
  //   const tokenId = 2
  //   const account = this.signers.owner
  //   const token = this.instances.owner.getTokenSignature(this.contractAddress) || {
  //     signature: "",
  //     publicKey: "",
  //   };
  //   const nftContract = new ethers.Contract(process.env.ERC_721 as string, abiERC721, account);
  //   if (await nftContract.ownerOf(tokenId) !== account.address) {
  //     console.log(`${account.address} Not owner of NFT`);
  //     return;
  //   }
  //   const contract = this.blindAuctionContract.connect(account);
  //   const tx = await nftContract.approve(this.contractAddress, tokenId);
  //   await tx.wait();
  //   const transaction = await contract.setBidTokenId(process.env.ERC_721 as string, tokenId, BLIND_TIME);
  //   await transaction.wait();
  //   const owner = await contract.bidOwnerOf(process.env.ERC_721 as string, tokenId, token.publicKey, token.signature);
  //   expect(owner).to.equal(account.address);
  // });

  // it("Should bid a NFT", async function () {
  //   const tokenId = 2
  //   const account = this.signers.account1
  //   const contract = this.blindAuctionContract.connect(account);
  //   const token = this.instances.account1.getTokenSignature(this.contractAddress) || {
  //     signature: "",
  //     publicKey: "",
  //   };
  //   const amount = this.instances.account1.encrypt32(1);
  //   // Bid
  //   const erc20Contract: EncryptedERC20 = new ethers.Contract(process.env.ERC_20 as string, abiERC20, account);
  //   const tx = await erc20Contract.approve(this.contractAddress, amount);
  //   await tx.wait();
  //   console.log(tx.hash)
  //   const bid = await contract.bid(process.env.ERC_721 as string, tokenId, amount);
  //   await bid.wait();
  //   console.log(bid.hash);
  //   const bids = await contract.currentBidOf(token.publicKey, token.signature);
  //   console.log(bids);
  //   expect(bids.length).to.greaterThan(0);
  // });

  // it("Current Bid of User", async function () {
  //   const account = this.signers.account1
  //   const contract = this.blindAuctionContract.connect(account);
  //   const token = this.instances.account1.getTokenSignature(this.contractAddress) || {
  //     signature: "",
  //     publicKey: "",
  //   };
  //   const currentBidOfs = await contract.exploreBidingNFT(token.publicKey, token.signature);
  //   console.log("currentBidOfs");
  //   expect(currentBidOfs.length).to.greaterThan(0);
  // });

});
