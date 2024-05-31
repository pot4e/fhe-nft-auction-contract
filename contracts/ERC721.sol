// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Uncomment this line to use console.log

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract IncoNFT is ERC721Enumerable, Ownable {
    uint public currentTokenId = 0;

    address public mintOperator;
    string private _uri;
    
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

    constructor(string memory name, string memory symbol, string memory uri) ERC721(name, symbol) {
        _uri = uri;
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        return _uri;
    }

    function mint(address recipient) external onlyOwner {
        currentTokenId += 1;
        uint tokenId = currentTokenId;
        _safeMint(recipient, tokenId);
    }
}
