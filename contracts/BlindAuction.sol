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
    // Manager User
    // Set Bid -> nft address => tokenId => endTime
    mapping(IERC721 => mapping(uint256 => uint256)) internal nftEndTime;
    // Get user nfId => tokenId => user
    mapping(IERC721 => mapping(uint256 => address)) internal nftPostOwner;
    // user address => address => BidData[]
    mapping(address => BidData[]) public bidUsers;
    // user address => nft address => tokenId => bidAmount
    mapping(address => mapping(IERC721 => mapping(uint256 => euint32)))
        internal bidAmount;
    mapping(address => mapping(IERC721 => mapping(uint256 => bool)))
        internal isBiddedNFT;
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
            !isBiddedNFT[msg.sender][nft][tokenId],
            "User already bid for this NFT"
        );
        euint32 value = TFHE.asEuint32(encryptedValue);
        bidAmount[msg.sender][nft][tokenId] = value;
        isBiddedNFT[msg.sender][nft][tokenId] = true;
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

    function resetNFt(address user, IERC721 nft, uint256 tokenId) internal {
        //  Remove Post
        nftPostOwner[nft][tokenId] = address(0);
        nftEndTime[nft][tokenId] = 0;
        highestBidder[nft][tokenId] = address(0);
        highestBid[nft][tokenId] = TFHE.asEuint32(0);
        manualEndBid[nft][tokenId] = false;
        isAddedPostNFTid[nft][tokenId] = false;
        counters[nft][tokenId] = 0;
        // remove nft
        for (uint i = 0; i < postNFTs.length; i++) {
            IERC721 _nft = postNFTs[i];
            uint256[] memory _tokenIds = tokenIds[_nft];
            for (uint j = 0; j < _tokenIds.length; j++) {
                if (_nft == nft && _tokenIds[j] == tokenId) {
                    delete tokenIds[_nft][j];
                }
            }
        }
        // Remove Bid amount
        bidAmount[user][nft][tokenId] = TFHE.asEuint32(0);
        isBiddedNFT[user][nft][tokenId] = false;
        // Remove Bid data
        for (uint i = 0; i < bidUsers[user].length; i++) {
            BidData memory bidDetail = bidUsers[user][i];
            if (bidDetail.nft == nft && bidDetail.tokenId == tokenId) {
                delete bidUsers[user][i];
            }
        }
        // Remove Post NFt if no have token id
        for (uint i = 0; i < postNFTs.length; i++) {
            IERC721 _nft = postNFTs[i];
            uint256[] memory _tokenIds = tokenIds[_nft];
            if (_tokenIds.length == 0) {
                delete postNFTs[i];
            }
        }
    }

    // Refund for loser
    function refund(
        IERC721 nft,
        uint256 tokenId
    ) internal onlyAfterEnd(nft, tokenId) {
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
        // 1. Claim Post NFT not have bid
        NFT[] memory postNFTsEnded = listPostNFTEnded(msg.sender);
        for (uint i = 0; i < postNFTs.length; i++) {
            postNFTsEnded[i].nft.transferFrom(
                address(this),
                msg.sender,
                postNFTsEnded[i].tokenId
            );
            resetNFt(
                msg.sender,
                postNFTsEnded[i].nft,
                postNFTsEnded[i].tokenId
            );
        }
        // 2. Claim Winner NFT
        NFT[] memory winerNFTs = listNFTBidAndWin(msg.sender);
        for (uint i = 0; i < winerNFTs.length; i++) {
            winerNFTs[i].nft.transferFrom(
                address(this),
                msg.sender,
                winerNFTs[i].tokenId
            );
            resetNFt(msg.sender, winerNFTs[i].nft, winerNFTs[i].tokenId);
        }
        // 3. Refund Not winner NFT
        NFT[] memory loserNFTs = listNFTBidAndLose(msg.sender);
        euint32 totalRefund = TFHE.asEuint32(0);
        for (uint i = 0; i < loserNFTs.length; i++) {
            totalRefund = TFHE.add(
                totalRefund,
                bidAmount[msg.sender][loserNFTs[i].nft][loserNFTs[i].tokenId]
            );
            resetNFt(msg.sender, loserNFTs[i].nft, loserNFTs[i].tokenId);
        }
        if (TFHE.decrypt(TFHE.gt(totalRefund, TFHE.asEuint32(0)))) {
            paymentToken.transferFrom(address(this), msg.sender, totalRefund);
        }
    }

    function isClaimable() public view returns (bool) {
        return
            listPostNFTEnded(msg.sender).length > 0 ||
            listNFTBidAndWin(msg.sender).length > 0 ||
            listNFTBidAndLose(msg.sender).length > 0;
    }

    function listPostNFTEnded(
        address user
    ) internal view returns (NFT[] memory) {
        uint count = 0;
        for (uint i = 0; i < postNFTs.length; i++) {
            IERC721 nft = postNFTs[i];
            uint256[] memory _tokenIds = tokenIds[nft];
            for (uint j = 0; j < _tokenIds.length; j++) {
                if (isPostNFTEnded(user, nft, _tokenIds[j])) {
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
                if (isPostNFTEnded(user, nft, _tokenIds[j])) {
                    nftList[index] = nftDetail(nft, _tokenIds[j]);
                    index++;
                }
            }
        }
        return nftList;
    }

    // List NFT Bid and win by address
    function listNFTBidAndWin(
        address user
    ) internal view returns (NFT[] memory) {
        uint count = 0;
        for (uint i = 0; i < postNFTs.length; i++) {
            IERC721 nft = postNFTs[i];
            uint256[] memory _tokenIds = tokenIds[nft];
            for (uint j = 0; j < _tokenIds.length; j++) {
                if (isWinnerNFT(user, nft, _tokenIds[j])) {
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
                if (isWinnerNFT(user, nft, _tokenIds[j])) {
                    nftList[index] = nftDetail(nft, _tokenIds[j]);
                    index++;
                }
            }
        }
        return nftList;
    }

    // List NFT Bid and lose
    function listNFTBidAndLose(
        address user
    ) internal view returns (NFT[] memory) {
        uint count = 0;
        for (uint i = 0; i < postNFTs.length; i++) {
            IERC721 nft = postNFTs[i];
            uint256[] memory _tokenIds = tokenIds[nft];
            for (uint j = 0; j < _tokenIds.length; j++) {
                if (isLoserNFT(user, nft, _tokenIds[j])) {
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
                if (isLoserNFT(user, nft, _tokenIds[j])) {
                    nftList[index] = nftDetail(nft, _tokenIds[j]);
                    index++;
                }
            }
        }
        return nftList;
    }

    function isPostNFTEnded(
        address postAddress,
        IERC721 nft,
        uint256 tokenId
    ) internal view returns (bool) {
        return
            nftPostOwner[nft][tokenId] == postAddress &&
            highestBidder[nft][tokenId] == address(0) &&
            isNFTBidEnded(nft, tokenId);
    }

    function isWinnerNFT(
        address bidAdddress,
        IERC721 nft,
        uint256 tokenId
    ) internal view returns (bool) {
        return
            highestBidder[nft][tokenId] == bidAdddress &&
            isNFTBidEnded(nft, tokenId);
    }

    function isLoserNFT(
        address bidAdddress,
        IERC721 nft,
        uint256 tokenId
    ) internal view returns (bool) {
        return
            isBiddedNFT[bidAdddress][nft][tokenId] &&
            highestBidder[nft][tokenId] != bidAdddress &&
            isNFTBidEnded(nft, tokenId);
    }

    function isNFTBidEnded(
        IERC721 nft,
        uint256 tokenId
    ) internal view returns (bool) {
        return block.timestamp > nftEndTime[nft][tokenId];
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
