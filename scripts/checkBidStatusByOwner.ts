import * as dotenv from 'dotenv'
dotenv.config()
import { getConfigValue } from "./utils";
import abiJson from "../artifacts/contracts/BlindAuction.sol/BlindAuction.json";
import { ethers } from "ethers";
const address = process.env.address;
if (!address) {
    console.error("Please provide an address of bidder");
    process.exit(1);
}
const provider = new ethers.JsonRpcProvider("https://testnet.inco.org");
(async () => {
    const owner = new ethers.Wallet(process.env.PRIVATE_KEY_1 as string, provider)
    const contract = new ethers.Contract(getConfigValue("BLIND_AUCTION"), abiJson.abi, owner);
    const bids = await contract.bidsStatusByAddress(address);
    console.log(bids)
})()