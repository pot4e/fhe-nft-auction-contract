// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./EncryptedERC20.sol";
import "fhevm/lib/TFHE.sol";

contract MintTestNFT is Ownable {
    struct NFT {
        IERC721Enumerable nft;
        uint256 tokenId;
    }
    EncryptedERC20 public paymentToken;

    NFT[] public testNFTs;
    bool public isStopClaiming = false;
    uint256 public claimGap = 12 * 3600; // 12 hours

    mapping(address => uint256) public mintCountMap;
    mapping(address => uint256) public lastTimesMintMap;
    mapping(address => uint256) public lastTimesClaimTokenMap;

    constructor(EncryptedERC20 _paymentToken) {
        paymentToken = _paymentToken;
    }

    modifier canClaimNFT() {
        require(!isStopClaiming, "Claiming is stopped");
        require(testNFTs.length > 0, "No test NFTs available");
        require(
            mintCountMap[msg.sender] < 3
            || block.timestamp - lastTimesMintMap[msg.sender] >= claimGap
            || msg.sender == owner(),
            "You can only claim 3 test NFTs every 12h"
        );
        _;
    }

    modifier canClaimTestToken() {
        require(!isStopClaiming, "Claiming is stopped");
        require(
            block.timestamp - lastTimesClaimTokenMap[msg.sender] >= claimGap
            || msg.sender == owner(),
            "You can only claim test Token every 12h"
        );
        _;
    }

    // owner
    function setStopClaiming(bool _isStopClaiming) external onlyOwner {
        isStopClaiming = _isStopClaiming;
    }

    function addMoreTestNFTs(
        IERC721Enumerable nft,
        uint256 tokenId
    ) external onlyOwner {
        require(
            nft.ownerOf(tokenId) == msg.sender,
            "You are not owner of this NFT"
        );
        nft.transferFrom(msg.sender, address(this), tokenId);
        testNFTs.push(NFT(nft, tokenId));
    }

    function updateClaimGap(uint256 _claimGap) external onlyOwner {
        claimGap = _claimGap;
    }

    function claimTestNFT() external canClaimNFT {
        if (block.timestamp - lastTimesMintMap[msg.sender] >= claimGap) {
            lastTimesMintMap[msg.sender] = block.timestamp;
            mintCountMap[msg.sender] = 1;
        } else {
            mintCountMap[msg.sender] += 1;
        }
        uint rndIndex = uint(
            keccak256(abi.encodePacked(block.timestamp, msg.sender))
        ) % testNFTs.length; // random 1-10 tokens
        NFT memory iNFT = testNFTs[rndIndex];
        iNFT.nft.transferFrom(address(this), msg.sender, iNFT.tokenId);
        // remove minted NFT from testNFTs
        testNFTs[rndIndex] = testNFTs[testNFTs.length - 1];
        testNFTs.pop();
    }

    function claimTestToken() external canClaimTestToken {
        if (block.timestamp - lastTimesClaimTokenMap[msg.sender] >= claimGap) {
            lastTimesClaimTokenMap[msg.sender] = block.timestamp;
        }
        // Transfer bid token to user
        paymentToken.transfer(msg.sender, TFHE.asEuint32(150));
    }
}
