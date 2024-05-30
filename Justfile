mintNFT RECIPIENT SYMBOL:
    recipient={{RECIPIENT}} symbol={{SYMBOL}} npx hardhat run scripts/MintNFTSample.ts --network inco

deployNFTSample:
    npx hardhat run deploy/IncoNFTDeploy.ts --network inco

deploy-erc20-encrypted:
    npx hardhat run deploy/EncryptedERC20.ts --network inco 

checkBidsStatusByOwnerContract ADDRESS:
     address={{ADDRESS}} npx ts-node scripts/checkBidStatusByOwner.ts

checkYourStatus ADDRESS:
    address={{ADDRESS}} npx ts-node scripts/checkYourBidsStatus.ts