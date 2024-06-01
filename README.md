# NFT Auction Contracts
```

████████╗██╗  ██╗███████╗              ██╗███╗   ██╗ ██████╗ ██████╗ 
╚══██╔══╝██║  ██║██╔════╝              ██║████╗  ██║██╔════╝██╔═══██╗
   ██║   ███████║█████╗      █████╗    ██║██╔██╗ ██║██║     ██║   ██║
   ██║   ╚════██║██╔══╝      ╚════╝    ██║██║╚██╗██║██║     ██║   ██║
   ██║        ██║███████╗              ██║██║ ╚████║╚██████╗╚██████╔╝
   ╚═╝        ╚═╝╚══════╝              ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ 
                                                                     
```
## Overview

NFT Auction Platform is a use case that uses Inco Network's FHE technology to provide maximum security to users by confidential bid and encrypting user tokens. It allows users to post their NFTs for auction or bid on NFTs using INCO tokens powered by Inco FHE (Fully Homomorphic Encryption) technology. Our platform ensures secure, private, and transparent transactions for all users.

### dApp
```
https://inftco.daningyn.xyz/
```

### Contract Addresses

- Inco Testnet Token (ERC20): `0x8bC0Cc0783255Bc2A451b04C3850fA82a3e88C27`

- Blind Auction: `0x097C348E36bAD8065cAa9d576bE805c6764F99d4`

- Contract for users to claim test resources: `0x973004c9a429304fE6E448c977d1f39B35B01F2e`

## Pre Requisites

Install [pnpm](https://pnpm.io/installation)

Before being able to run any command, you need to create a `.env` file and set a BIP-39 compatible mnemonic as an
environment variable. If you don't already have a mnemonic, you can use this [website](https://iancoleman.io/bip39/) to
generate one. You can run the following command to use the example .env:

```sh
cp .env.example .env
```
Then, proceed with installing dependencies:

```sh
pnpm install
```

## Compile

Compile the smart contracts with Hardhat:

```sh
npx hardhat compile --network inco
```

## TypeChain

Compile the smart contracts and generate TypeChain bindings:

```sh
pnpm typechain
```
(For more control over the deployment process, you can rewrite the deployment script (deploy.ts) and use the command
`npx hardhat run scripts/deploy.ts --network inco` to deploy your contracts.)

## Deploy

Deploy the ERC20 to Inco Gentry Testnet Network:

```sh
just deploy-erc20-encrypted
```
Deploy the BlindAuction to Inco Gentry Testnet Network:

```sh
just deploy-nft-blind-auction
```
Deploy contract for users to claim test tokens

```sh
just deploy-mint-testnft
```

### Test

Run the tests with Hardhat:

```sh
npx hardhat test --network inco
```

Run Blind Client Test

```sh
 ts-node test/BlindAuctionClient.ts 
```

 # License
This project is licensed under the MIT License. See the LICENSE file for details.

# Contact
For any questions or support, please contact us at daningyn@t4e.xyz