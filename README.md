# FHE-contract-example
### Pre Requisites

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

### Compile

Compile the smart contracts with Hardhat:

```sh
npx hardhat compile --network inco
```

### TypeChain

Compile the smart contracts and generate TypeChain bindings:

```sh
pnpm typechain
```
(For more control over the deployment process, you can rewrite the deployment script (deploy.ts) and use the command
`npx hardhat run scripts/deploy.ts --network inco` to deploy your contracts.)

### Deploy

Deploy the ERC20 to Inco Gentry Testnet Network:

```sh
npx hardhat run deploy/EncryptedERC20.ts --network inco 
```
Deploy the BlindAuction to Inco Gentry Testnet Network:

```sh
npx hardhat run deploy/BlindAuction.ts --network inco 
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