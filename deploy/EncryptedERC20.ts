import hre, { ethers } from "hardhat";
import { createInstances } from "../test/instance";
import { getSigners } from "../test/signers";
(async () => {
    const [owner, account1, account2] = await hre.ethers.getSigners();

    const contractFactory = await ethers.getContractFactory("EncryptedERC20");
    const contract = await contractFactory.connect(owner).deploy();
    await contract.waitForDeployment();
    const contractAddress = await contract.getAddress();
    console.log("EncryptedERC20 deployed to: ", await contract.getAddress());
    const instances = await createInstances(contractAddress, ethers, await getSigners(ethers));
    const encryptedAmount = instances.owner.encrypt32(Number(100_0000_000));
    const tx = await contract.mint(encryptedAmount);
    await tx.wait();
    console.log("Minted 100_0000_000 tokens to owner", tx.hash)
    const token = instances.owner.getTokenSignature(contractAddress) || {
        signature: "",
        publicKey: "",
    };
    const encryptedBalance = await contract.balanceOf(token.publicKey, token.signature);
    const balance = instances.owner.decrypt(contractAddress, encryptedBalance);
    console.log("Balance of owner", balance.toString())
    const txTransfer1 = await contract["transfer(address,bytes)"](account1.address, instances.account1.encrypt32(1000));
    await txTransfer1.wait();
    console.log(`Transfer 1000 tokens to ${account1.address}`, txTransfer1.hash)

    const txTransfer2 = await contract["transfer(address,bytes)"](account2.address, instances.account2.encrypt32(1000));
    await txTransfer2.wait();
    console.log(`Transfer 1000 tokens to ${account2.address}`, txTransfer2.hash)
})()