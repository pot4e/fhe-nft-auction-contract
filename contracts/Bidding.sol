// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./ProofOfBidERC721.sol";

contract Bidding {
    // NFT tokenIds for Bid
    struct Bid {
        address bidder;
        uint tokenId;
        uint amount;
    }
    uint[] tokenIds;
    Bid[] public bids;
    ProofOfBidERC721 public proofNFT;

    constructor(uint[] memory _tokenIds, address _nftAddress) {
        tokenIds = _tokenIds;
        proofNFT = ProofOfBidERC721(_nftAddress);
    }

    function bid(uint tokenId) external payable {
        require(msg.value != 0, "Bid amount must be greater than 0");
        require(isTokenExist(tokenId), "Token does not exist");
        require(!isBidderExist(msg.sender, tokenId), "Bidder already exist");
        // Add bid to the list
        bids.push(Bid(msg.sender, tokenId, msg.value));
        // Mint NFT
        proofNFT.mintProof(msg.sender, tokenId, msg.value);
    }

    function isBidderExist(
        address bidder,
        uint tokenId
    ) public view returns (bool) {
        for (uint i = 0; i < bids.length; i++) {
            if (bids[i].bidder == bidder && bids[i].tokenId == tokenId) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Check if the token exists
     */
    function isTokenExist(uint tokenId) public view returns (bool) {
        for (uint i = 0; i < tokenIds.length; i++) {
            if (tokenIds[i] == tokenId) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Get the winner of the bid
     */
    function getWinner() public view returns (address) {
        address winner = address(0);
        uint lowestBid = 0;
        for (uint i = 0; i < bids.length; i++) {
            if (bids[i].amount < lowestBid) {
                lowestBid = bids[i].amount;
                winner = bids[i].bidder;
            }
        }
        return winner;
    }

    function getBidderBids(address bidder) public view returns (Bid[] memory) {
        Bid[] memory result = new Bid[](bids.length);
        uint counter = 0;
        for (uint i = 0; i < bids.length; i++) {
            if (bids[i].bidder == bidder) {
                result[counter] = bids[i];
                counter++;
            }
        }
        return result;
    }
}
