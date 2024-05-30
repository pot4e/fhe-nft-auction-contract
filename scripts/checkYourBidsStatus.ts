import * as dotenv from 'dotenv'
dotenv.config()
import { getConfigValue } from "./utils";
import abiJson from "../artifacts/contracts/BlindAuction.sol/BlindAuction.json";
import { ethers } from "ethers";
const address = process.env.address;
if (!address) {
    console.error("Please provide your address");
    process.exit(1);
}
const provider = new ethers.JsonRpcProvider("https://testnet.inco.org");
(async () => {
    const wallets = [
        new ethers.Wallet(process.env.PRIVATE_KEY_1 as string, provider),
        new ethers.Wallet(process.env.PRIVATE_KEY_2 as string, provider),
        new ethers.Wallet(process.env.PRIVATE_KEY_3 as string, provider)]
    const yourWallet = wallets.find(wallet => wallet.address === address);
    if (!yourWallet) {
        console.log('Wallet not found!')
        process.exit(1);
    }
    const contract = new ethers.Contract(getConfigValue("BLIND_AUCTION"), abiJson.abi, yourWallet);
    const bids = await contract.bidsStatusOf();
    console.log(bids)
})()