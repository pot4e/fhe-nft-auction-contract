// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ProofOfBidERC721 is ERC721 {
    uint public currentTokenId = 0;
    struct Bid {
        address bidder;
        uint tokenId;
        uint amount;
    }
    mapping(uint => Bid) public bids;

    address public owner;
    address public mintOperator;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    modifier onlyMintOperator() {
        require(
            msg.sender == mintOperator,
            "Only mint owner can call this function"
        );
        _;
    }

    function setMintOwner(address _mintOwner) external onlyOwner {
        mintOperator = _mintOwner;
    }

    constructor() ERC721("ProofOfBidNFT", "T4ENFT") {
        owner = msg.sender;
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        // TODO iamge url
        return "";
    }

    function mintProof(
        address recipient,
        uint bidTokenId,
        uint bitAmout
    ) external onlyMintOperator returns (uint) {
        currentTokenId += 1;
        uint tokenId = currentTokenId;
        _safeMint(recipient, tokenId);
        bids[tokenId] = Bid(recipient, bidTokenId, bitAmout);
        return tokenId;
    }
}
