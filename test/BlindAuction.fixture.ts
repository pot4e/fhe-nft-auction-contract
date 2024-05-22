import hre, { ethers } from "hardhat";

import type { BlindAuction } from "../types";
import { getSigners } from "./signers";

export async function deployBlindAuctionFixture(): Promise<BlindAuction> {
  const signers = await getSigners(ethers);
  const contractFactory = await ethers.getContractFactory("BlindAuction");
  const contract = await contractFactory.connect(signers.owner).deploy(process.env.ERC_20 as string);
  await contract.waitForDeployment();

  return contract;
}
