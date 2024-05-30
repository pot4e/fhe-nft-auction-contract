// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "fhevm/lib/TFHE.sol";
import "fhevm/abstracts/EIP712WithModifier.sol";
import "./EncryptedERC20.sol";

contract BlindAuction is EIP712WithModifier {
    // Contract owner
    address public owner;

    EncryptedERC20 public paymentToken;

    struct BidData {
        address bidder;
        IERC721 nft;
        uint256 tokenId;
        euint32 amount;
        uint256 timstamp;
    }

    struct BidDataStatus {
        address bidder;
        IERC721 nft;
        uint256 tokenId;
        bytes amount;
        uint256 timstamp;
        bool isWinner;
    }

    struct BidSatus {
        IERC721 nft;
        uint256 tokenId;
        bool isWinner;
    }

    struct NFT {
        address postOwner;
        IERC721 nft;
        uint256 tokenId;
        uint256 endTime;
        uint256 bidConters;
    }
    // Manager POST NFT
    IERC721[] public postNFTs;
    mapping(IERC721 => bool) isAddedPostNFTContract;
    mapping(IERC721 => mapping(uint256 => bool)) isAddedPostNFTid;
    mapping(IERC721 => uint256[]) public tokenIds;
    // Manager bid user
    // Set Bid -> nft address => tokenId => endTime
    mapping(IERC721 => mapping(uint256 => uint256)) internal nftEndTime;
    // Get user nfId => tokenId => user
    mapping(IERC721 => mapping(uint256 => address)) internal nftPostOwner;
    // user address => address => BidData[]
    mapping(address => BidData[]) public bidUsers;
    mapping(address => mapping(IERC721 => mapping(uint256 => bool)))
        internal isBidded;
    // nfId => nftaddres => tokenId => address
    mapping(IERC721 => mapping(uint256 => address)) public highestBidder;
    // nftId => amount
    mapping(IERC721 => mapping(uint256 => euint32)) public highestBid;
    // NFT => tokenId => manual end bid
    mapping(IERC721 => mapping(uint256 => bool)) public manualEndBid;
    // NFT => tokenId => counter
    mapping(IERC721 => mapping(uint256 => uint256)) public counters;

    error TooEarly(uint256 time);

    error TooLate(uint256 time);

    event Winner(address who);

    constructor(
        EncryptedERC20 _paymentToken
    ) EIP712WithModifier("Authorization token", "1") {
        paymentToken = _paymentToken;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    modifier onlyBeforeEnd(IERC721 nft, uint256 tokenId) {
        if (block.timestamp >= nftEndTime[nft][tokenId])
            revert TooLate(nftEndTime[nft][tokenId]);
        _;
    }

    modifier onlyAfterEnd(IERC721 nft, uint256 tokenId) {
        if (block.timestamp <= nftEndTime[nft][tokenId])
            revert TooEarly(nftEndTime[nft][tokenId]);
        _;
    }

    function setBidTokenId(
        IERC721 nft,
        uint256 tokenId,
        uint256 duration
    ) external {
        require(duration > 0, "Duration must be greater than 0");
        require(nftPostOwner[nft][tokenId] == address(0), "NFT id already set");
        require(
            nft.ownerOf(tokenId) == msg.sender,
            "Your are not owner of this NFT"
        );
        nft.transferFrom(msg.sender, address(this), tokenId);
        if (!isAddedPostNFTContract[nft]) {
            isAddedPostNFTContract[nft] = true;
            postNFTs.push(nft);
        }
        if (!isAddedPostNFTid[nft][tokenId]) {
            isAddedPostNFTid[nft][tokenId] = true;
            tokenIds[nft].push(tokenId);
        }
        nftEndTime[nft][tokenId] = block.timestamp + duration;
        nftPostOwner[nft][tokenId] = msg.sender;
    }

    function bid(
        IERC721 nft,
        uint256 tokenId,
        bytes calldata encryptedValue
    ) public onlyBeforeEnd(nft, tokenId) {
        require(nftPostOwner[nft][tokenId] != msg.sender, "Owner can't bid");
        require(nftPostOwner[nft][tokenId] != address(0), "Invalid token id");
        require(
            !isBidded[msg.sender][nft][tokenId],
            "User already bid for this NFT"
        );
        euint32 value = TFHE.asEuint32(encryptedValue);
        //
        isBidded[msg.sender][nft][tokenId] = true;
        bidUsers[msg.sender].push(
            BidData({
                bidder: msg.sender,
                nft: nft,
                tokenId: tokenId,
                amount: value,
                timstamp: block.timestamp
            })
        );
        // transfer token to contract
        paymentToken.transferFrom(msg.sender, address(this), value);
        // Update counter
        counters[nft][tokenId] = counters[nft][tokenId] + 1;
        // Update highest bid
        euint32 currentHightestBid = highestBid[nft][tokenId];
        ebool isHigher = TFHE.lt(currentHightestBid, value);
        if (TFHE.decrypt(isHigher)) {
            highestBid[nft][tokenId] = value;
        }
        highestBidder[nft][tokenId] = msg.sender;
    }

    // get Bid user by tokenId and address
    function getBidOfUser(
        IERC721 nft,
        uint256 tokenId,
        address user
    ) internal view returns (BidData memory) {
        BidData[] memory bids = bidUsers[user];
        for (uint256 i = 0; i < bids.length; i++) {
            if (
                bids[i].bidder == user &&
                bids[i].nft == nft &&
                bids[i].tokenId == tokenId
            ) {
                return bids[i];
            }
        }
        return
            BidData({
                bidder: address(0),
                nft: IERC721(address(0)),
                tokenId: 0,
                amount: TFHE.asEuint32(0),
                timstamp: 0
            });
    }

    // Claim nft for winner
    function claimNFT(
        IERC721 nft,
        uint256 tokenId
    ) external onlyAfterEnd(nft, tokenId) {
        require(
            highestBidder[nft][tokenId] == msg.sender,
            "Only winner can call this function"
        );
        nft.transferFrom(address(this), msg.sender, tokenId);
        resetNFt(nft, tokenId);
        emit Winner(msg.sender);
    }

    function resetNFt(IERC721 nft, uint256 tokenId) internal {
        // TODO remove nft
        nftPostOwner[nft][tokenId] = address(0);
        nftEndTime[nft][tokenId] = 0;
        highestBidder[nft][tokenId] = address(0);
        highestBid[nft][tokenId] = TFHE.asEuint32(0);
        manualEndBid[nft][tokenId] = false;
    }

    // Refund for loser
    function refund(
        IERC721 nft,
        uint256 tokenId
    ) external onlyAfterEnd(nft, tokenId) {
        require(
            highestBidder[nft][tokenId] != msg.sender,
            "Only loser can call this function"
        );
        BidData memory existingBidData = getBidOfUser(nft, tokenId, msg.sender);
        require(
            existingBidData.bidder != address(0),
            "User not bid for this NFT"
        );
        paymentToken.transfer(msg.sender, existingBidData.amount);
    }

    // Lidy bid user
    function bidOwnerOf(
        IERC721 nft,
        uint256 tokenId,
        bytes32 publicKey,
        bytes calldata signature
    )
        external
        view
        onlySignedPublicKey(publicKey, signature)
        returns (address)
    {
        return nftPostOwner[nft][tokenId];
    }

    function getHidgerBidder(
        IERC721 nft,
        uint256 tokenId
    ) external view onlyAfterEnd(nft, tokenId) returns (address) {
        return highestBidder[nft][tokenId];
    }

    // Claim All winer NFT by address
    function claimAllNFT() external {
        BidData[] memory bids = bidUsers[msg.sender];
        for (uint i = 0; i < bids.length; i++) {
            bool isWinner = highestBidder[bids[i].nft][bids[i].tokenId] ==
                msg.sender &&
                block.timestamp > nftEndTime[bids[i].nft][bids[i].tokenId];
            if (isWinner) {
                postNFTs[i].transferFrom(
                    address(this),
                    msg.sender,
                    bids[i].tokenId
                );
                resetNFt(postNFTs[i], bids[i].tokenId);
            }
        }
    }

    /**
     * Explorers
     */
    function exploreBidingNFT() external view returns (NFT[] memory) {
        uint count = 0;

        // First, count the number of valid NFTs
        for (uint i = 0; i < postNFTs.length; i++) {
            IERC721 nft = postNFTs[i];
            uint256[] memory _tokenIds = tokenIds[nft];
            for (uint j = 0; j < _tokenIds.length; j++) {
                if (block.timestamp < nftEndTime[nft][_tokenIds[j]]) {
                    count++;
                }
            }
        }

        // Initialize the array with the correct size
        NFT[] memory nftList = new NFT[](count);
        uint index = 0;

        // Populate the array with valid NFTs
        for (uint i = 0; i < postNFTs.length; i++) {
            IERC721 nft = postNFTs[i];
            uint256[] memory _tokenIds = tokenIds[nft];
            for (uint j = 0; j < _tokenIds.length; j++) {
                if (block.timestamp < nftEndTime[nft][_tokenIds[j]]) {
                    nftList[index] = nftDetail(nft, _tokenIds[j]);
                    index++;
                }
            }
        }

        return nftList;
    }

    function exploreEndingNFT() external view returns (NFT[] memory) {
        uint count = 0;

        // First, count the number of ending NFTs
        for (uint i = 0; i < postNFTs.length; i++) {
            IERC721 nft = postNFTs[i];
            uint256[] memory _tokenIds = tokenIds[nft];
            for (uint j = 0; j < _tokenIds.length; j++) {
                if (block.timestamp > nftEndTime[nft][_tokenIds[j]]) {
                    count++;
                }
            }
        }

        // Initialize the array with the correct size
        NFT[] memory nftList = new NFT[](count);
        uint index = 0;

        // Populate the array with ending NFTs
        for (uint i = 0; i < postNFTs.length; i++) {
            IERC721 nft = postNFTs[i];
            uint256[] memory _tokenIds = tokenIds[nft];
            for (uint j = 0; j < _tokenIds.length; j++) {
                if (block.timestamp > nftEndTime[nft][_tokenIds[j]]) {
                    nftList[index] = nftDetail(nft, _tokenIds[j]);
                    index++;
                }
            }
        }

        return nftList;
    }

    function nftDetail(
        IERC721 nft,
        uint256 tokenId
    ) public view returns (NFT memory) {
        return
            NFT({
                postOwner: nftPostOwner[nft][tokenId],
                nft: nft,
                tokenId: tokenId,
                endTime: nftEndTime[nft][tokenId],
                bidConters: counters[nft][tokenId]
            });
    }

    function allBidOf(
        bytes32 publicKey,
        bytes calldata signature
    )
        external
        view
        onlySignedPublicKey(publicKey, signature)
        returns (BidDataStatus[] memory)
    {
        BidData[] memory bids = bidUsers[msg.sender];
        BidDataStatus[] memory bidStatus = new BidDataStatus[](bids.length);
        for (uint i = 0; i < bids.length; i++) {
            BidData memory newBid = bids[i];
            bool isWinner = highestBidder[newBid.nft][newBid.tokenId] ==
                msg.sender &&
                block.timestamp > nftEndTime[newBid.nft][newBid.tokenId];
            bytes memory amountEndcode = TFHE.reencrypt(
                newBid.amount,
                publicKey
            );
            bidStatus[i] = BidDataStatus({
                bidder: newBid.bidder,
                nft: newBid.nft,
                tokenId: newBid.tokenId,
                amount: amountEndcode,
                timstamp: newBid.timstamp,
                isWinner: isWinner
            });
        }
        return bidStatus;
    }

    function currentBidingOf(
        bytes32 publicKey,
        bytes calldata signature
    )
        external
        view
        onlySignedPublicKey(publicKey, signature)
        returns (BidDataStatus[] memory)
    {
        BidData[] memory bids = bidUsers[msg.sender];
        uint count = countValidBids(bids);

        BidDataStatus[] memory bidStatus = new BidDataStatus[](count);
        populateBidStatus(bids, bidStatus, publicKey);

        return bidStatus;
    }

    function countValidBids(
        BidData[] memory bids
    ) internal view returns (uint) {
        uint count = 0;
        for (uint i = 0; i < bids.length; i++) {
            if (block.timestamp < nftEndTime[bids[i].nft][bids[i].tokenId]) {
                count++;
            }
        }
        return count;
    }

    function populateBidStatus(
        BidData[] memory bids,
        BidDataStatus[] memory bidStatus,
        bytes32 publicKey
    ) internal view {
        uint index = 0;
        for (uint i = 0; i < bids.length; i++) {
            BidData memory newBid = bids[i];
            if (block.timestamp < nftEndTime[newBid.nft][newBid.tokenId]) {
                bytes memory amountEncode = TFHE.reencrypt(
                    newBid.amount,
                    publicKey
                );

                bidStatus[index] = BidDataStatus({
                    bidder: newBid.bidder,
                    nft: newBid.nft,
                    tokenId: newBid.tokenId,
                    amount: amountEncode,
                    timstamp: newBid.timstamp,
                    isWinner: false
                });

                index++;
            }
        }
    }

    function postNFTsOf(
        bytes32 publicKey,
        bytes calldata signature
    )
        external
        view
        onlySignedPublicKey(publicKey, signature)
        returns (NFT[] memory)
    {
        // Count the number of NFTs owned by the sender
        uint count = 0;
        for (uint i = 0; i < postNFTs.length; i++) {
            IERC721 nft = postNFTs[i];
            uint256[] memory _tokenIds = tokenIds[nft];
            for (uint j = 0; j < _tokenIds.length; j++) {
                if (nftPostOwner[nft][_tokenIds[j]] == msg.sender) {
                    count++;
                }
            }
        }

        // Initialize the array with the correct size
        NFT[] memory nftList = new NFT[](count);
        uint index = 0;

        // Populate the array with the sender's NFTs
        for (uint i = 0; i < postNFTs.length; i++) {
            IERC721 nft = postNFTs[i];
            uint256[] memory _tokenIds = tokenIds[nft];
            for (uint j = 0; j < _tokenIds.length; j++) {
                if (nftPostOwner[nft][_tokenIds[j]] == msg.sender) {
                    nftList[index] = nftDetail(nft, _tokenIds[j]);
                    index++;
                }
            }
        }

        return nftList;
    }

    // Bid status

    function getBidsStatusOfAddress(
        address user
    ) internal view returns (BidSatus[] memory) {
        BidData[] memory bids = bidUsers[user];
        BidSatus[] memory bidStatus = new BidSatus[](bids.length);
        for (uint i = 0; i < bids.length; i++) {
            BidData memory newBid = bids[i];
            bool isWinner = highestBidder[newBid.nft][newBid.tokenId] == user &&
                block.timestamp > nftEndTime[newBid.nft][newBid.tokenId];
            bidStatus[i] = BidSatus({
                nft: newBid.nft,
                tokenId: newBid.tokenId,
                isWinner: isWinner
            });
        }
        return bidStatus;
    }

    function bidsStatusByAddress(
        address user
    ) external view onlyOwner returns (BidSatus[] memory) {
        return getBidsStatusOfAddress(user);
    }

    function bidsStatusOf() external view returns (BidSatus[] memory) {
        return getBidsStatusOfAddress(msg.sender);
    }
}
