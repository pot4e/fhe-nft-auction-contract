import type { FhevmInstance } from "fhevmjs";

import { BlindAuction } from "../types";
import type { Signers } from "./signers";

declare module "mocha" {
  export interface Context {
    signers: Signers;
    contractAddress: string;
    instances: FhevmInstances;
    blindAuctionContract: BlindAuction;
  }
}

export interface FhevmInstances {
  owner: FhevmInstance;
  account1: FhevmInstance;
  account2: FhevmInstance;
}
