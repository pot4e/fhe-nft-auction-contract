import "@nomicfoundation/hardhat-toolbox";
import { config as dotenvConfig } from "dotenv";
import "hardhat-deploy";
import type { HardhatUserConfig } from "hardhat/config";
import type { NetworkUserConfig } from "hardhat/types";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
import { resolve } from "path";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });
export function getChainConfig(): NetworkUserConfig {
  return {
    accounts: [
      process.env.PRIVATE_KEY_1 as string,
      process.env.PRIVATE_KEY_2 as string,
      process.env.PRIVATE_KEY_3 as string
    ],
    chainId: 9090,
    url: "https://testnet.inco.org",
  }
}
const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.22",
    settings: {
      metadata: {
        // Not including the metadata hash
        // https://github.com/paulrberg/hardhat-template/issues/31
        bytecodeHash: "none",
      },
      // Disable the optimizer when debugging
      // https://hardhat.org/hardhat-network/#solidity-optimizer-support
      optimizer: {
        enabled: true,
        runs: 800,
      },
    },
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
  },
  namedAccounts: {
    deployer: 0,
  },
  mocha: {
    timeout: 180000,
  },
  gasReporter: {
    currency: "USD",
    enabled: process.env.REPORT_GAS ? true : false,
    excludeContracts: [],
    src: "./contracts",
  },
  networks: {
    hardhat: {
      chainId: 31337,
    },
    inco: getChainConfig(),
  },
  typechain: {
    outDir: "types",
    target: "ethers-v6",
  },
};

export default config;
