import type { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/dist/src/signer-with-address";

export interface Signers {
  owner: SignerWithAddress;
  account1: SignerWithAddress;
  account2: SignerWithAddress;
}

export const getSigners = async (ethers: any): Promise<Signers> => {
  const signers = await ethers.getSigners();
  return {
    owner: signers[0],
    account1: signers[1],
    account2: signers[2],
  };
};
