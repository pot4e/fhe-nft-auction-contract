import { AbiCoder, ethers } from "ethers";
import { FhevmInstance, createInstance } from "fhevmjs";
import * as dotenv from 'dotenv'
import inquirer from 'inquirer'
dotenv.config()
const blindContract = process.env.BLIND_AUCTION as string;
import abiJson from "../artifacts/contracts/BlindAuction.sol/BlindAuction.json";
import nftABIJson from "../test/erc721Abi.json";
import erc20ABI from "../test/erc20Abi.json";
const provider = new ethers.JsonRpcProvider("https://testnet.inco.org");
const BLIND_DURATION = 24 * 60 * 60 * 1000;
let instance: FhevmInstance;
const wallets = [
    new ethers.Wallet(process.env.PRIVATE_KEY_1 as string, provider),
    new ethers.Wallet(process.env.PRIVATE_KEY_2 as string, provider),
    new ethers.Wallet(process.env.PRIVATE_KEY_3 as string, provider)]

const createFhevmInstance = async () => {
    const network = await provider.getNetwork();
    const chainId = +network.chainId.toString();

    // Get the network's private key
    const ret = await provider.call({
        to: "0x000000000000000000000000000000000000005d",
        // first four bytes of keccak256('fhePubKey(bytes1)') + 1 byte for library
        data: '0xd9d47bb001',
    });
    const decoded = AbiCoder.defaultAbiCoder().decode(['bytes'], ret);
    const publicKey = decoded[0];
    // Create a client-side instance
    instance = await createInstance({ chainId, publicKey });
};

export const getTokenSignature = async (contractAddress: string, wallet: ethers.Wallet) => {
    const eip712Domain = {
        // This defines the network, in this case, Gentry Testnet.
        chainId: 9090,
        // Give a user-friendly name to the specific contract you're signing for.
        // MUST match the string in contract constructor (EIP712Modifier).
        name: 'Authorization token',
        // // Add a verifying contract to make sure you're establishing contracts with the proper entity.
        verifyingContract: contractAddress,
        // This identifies the latest version.
        // MUST match the version in contract constructor (EIP712Modifier).
        version: '1',
    };

    const reencryption = instance.generatePublicKey(eip712Domain);

    const signature = await wallet.signTypedData(
        reencryption.eip712.domain,
        { Reencrypt: reencryption.eip712.types.Reencrypt },
        reencryption.eip712.message
    )
    instance.setSignature(contractAddress, signature);

    const publicKey = instance.getPublicKey(contractAddress)!!.publicKey;
    return { signature, publicKey };
};

async function erc20Balance(wallet: ethers.Wallet): Promise<number> {
    const contract = new ethers.Contract(process.env.ERC_20 as string, erc20ABI, wallet);
    const { publicKey, signature } = await getTokenSignature(
        process.env.ERC_20 as string,
        wallet
    );
    const encryptedBalance = await contract.balanceOf(publicKey, signature);
    const balance = instance.decrypt(process.env.ERC_20 as string, encryptedBalance);
    return balance
}

async function exploreBidding() {
    const contract = new ethers.Contract(blindContract, abiJson.abi, provider);
    const bidingNFts = await contract.exploreBidingNFT();
    console.log(bidingNFts);
}
async function exploresEnding() {
    const contract = new ethers.Contract(blindContract, abiJson.abi, provider);
    const bidingNFts = await contract.exploreEndingNFT();
    console.log(bidingNFts);
}
async function biddingOfAddress() {
    const { address } = await inquirer.prompt([
        {
            type: 'rawlist',
            name: 'address',
            message: 'Select Wallet:',
            default: wallets[0].address,
            choices: wallets.map((wallet) => wallet.address),
        },
    ])
    const wallet = wallets.find((wallet) => wallet.address === address);
    if (!wallet) {
        console.error('Wallet not found');
        return;
    }
    const { publicKey, signature } = await getTokenSignature(
        blindContract,
        wallet
    );
    const contract = new ethers.Contract(blindContract, abiJson.abi, wallet);
    const bids = await contract.currentBidingOf(publicKey, signature);
    for (const bid of bids) {
        console.log("Bid: ", bid);
        console.log("Amount: ", instance!!.decrypt(blindContract, bid.amount));
    }
}
async function postNFTsOfAddress() {
    const { address } = await inquirer.prompt([
        {
            type: 'rawlist',
            name: 'address',
            message: 'Select Wallet:',
            default: wallets[0].address,
            choices: wallets.map((wallet) => wallet.address),
        },
    ])
    const wallet = wallets.find((wallet) => wallet.address === address);
    if (!wallet) {
        console.error('Wallet not found');
        return;
    }
    const { publicKey, signature } = await getTokenSignature(
        blindContract,
        wallet
    );
    const contract = new ethers.Contract(blindContract, abiJson.abi, wallet);
    const nfts = await contract.postNFTsOf(publicKey, signature);
    console.log(nfts);
}
async function postNFT() {
    const { address } = await inquirer.prompt([
        {
            type: 'rawlist',
            name: 'address',
            message: 'Select Wallet:',
            default: wallets[0].address,
            choices: wallets.map((wallet) => wallet.address),
        },
    ])
    const { nft, tokenId } = await inquirer.prompt([
        {
            type: 'number',
            name: 'nft',
            message: 'NFT Contract Address:',
            default: process.env.ERC_721,
        },
        {
            type: 'number',
            name: 'tokenId',
            message: 'Token ID:',
            default: 1,
        },
    ])
    const wallet = wallets.find((wallet) => wallet.address === address);
    if (!wallet) {
        console.error('Wallet not found');
        return;
    }
    // Approve
    const nftContract = new ethers.Contract(nft, nftABIJson, wallet);
    const txApproval = await nftContract.approve(blindContract, tokenId);
    await txApproval.wait();
    // Post NFT
    const contract = new ethers.Contract(blindContract, abiJson.abi, wallet);
    const tx = await contract.setBidTokenId(nft, tokenId, BLIND_DURATION);
    await tx.wait();
    console.info("NFT posted: ", tx.hash);
}
async function bidNFT() {
    const { address } = await inquirer.prompt([
        {
            type: 'rawlist',
            name: 'address',
            message: 'Select Wallet:',
            default: wallets[0].address,
            choices: wallets.map((wallet) => wallet.address),
        },
    ])
    const { nft, tokenId, amount } = await inquirer.prompt([
        {
            type: 'input',
            name: 'nft',
            message: 'NFT Contract Address:',
            default: process.env.ERC_721,
        },
        {
            type: 'number',
            name: 'tokenId',
            message: 'Token ID:',
            default: 1,
        },
        {
            type: 'number',
            name: 'amount',
            message: 'Amount:',
            default: 1,
        },
    ])
    const wallet = wallets.find((wallet) => wallet.address === address);
    if (!wallet) {
        console.error('Wallet not found');
        return;
    }
    const encryptedAmount = instance!!.encrypt32(amount);
    const erc20Contract = new ethers.Contract(process.env.ERC_20 as string, erc20ABI, wallet);
    const txApproval = await erc20Contract.approve(blindContract, encryptedAmount);
    await txApproval.wait();

    const contract = new ethers.Contract(blindContract, abiJson.abi, wallet);
    const tx = await contract.bid(nft, tokenId, encryptedAmount);
    await tx.wait();
    console.info("Bid placed", tx.hash);
}

async function transferToken() {
    const { address } = await inquirer.prompt([
        {
            type: 'rawlist',
            name: 'address',
            message: 'Select Wallet:',
            default: wallets[0].address,
            choices: wallets.map((wallet) => wallet.address),
        },
    ])
    const { to, amount } = await inquirer.prompt([
        {
            type: 'input',
            name: 'to',
            message: 'To Address:',
            default: wallets[1].address,
        },
        {
            type: 'number',
            name: 'amount',
            message: 'Amount:',
            default: 1,
        },
    ])
    const wallet = wallets.find((wallet) => wallet.address === address);
    if (!wallet) {
        console.error('Wallet not found');
        return;
    }
    const encryptedAmount = instance!!.encrypt32(amount);
    const erc20Contract = new ethers.Contract(process.env.ERC_20 as string, erc20ABI, wallet);
    const tx = await erc20Contract["transfer(address,bytes)"](to, encryptedAmount);
    await tx.wait();
    console.info("Transfer completed", tx.hash);
}
async function main() {
    await createFhevmInstance();
    const { task } = await inquirer.prompt([
        {
            type: 'rawlist',
            name: 'task',
            message: 'Blind Auction NFT:',
            default: 'Buy Username',
            choices: [
                'Explore Binding NFTs',
                'Explore Ending NFTs',
                'Post a NFT to bid',
                'Bid a NFT',
                'List Bidding NFTs of Address',
                'List Post NFTs of Address',
                "Transfer ERC20 Encrypted Token",
            ],
        },
    ])
    switch (task) {
        case 'Explore Binding NFTs':
            await exploreBidding();
            break;
        case 'Explore Ending NFTs':
            await exploresEnding()
            break
        case 'List Post NFTs of Address':
            await postNFTsOfAddress();
            break
        case 'List Bidding NFTs of Address':
            await biddingOfAddress();
            break
        case 'Post a NFT to bid':
            await postNFT();
            break
        case 'Bid a NFT':
            await bidNFT();
            break
        case 'Transfer ERC20 Encrypted Token':
            await transferToken();
            break
        default:
            break;
    }
}
main().then(() => {
    process.exit(0);
}).catch((error) => {
    console.error(error);
    process.exit(1);
});