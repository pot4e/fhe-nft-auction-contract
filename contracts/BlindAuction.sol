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

    uint public bidCounters;
    uint public postCounters;

    struct BidData {
        uint nftPostCounter;
        address bidder;
        IERC721 nft;
        uint256 tokenId;
        euint32 amount;
        uint256 bidTime;
    }

    struct BidDataStatus {
        uint nftPostCounter;
        address bidder;
        IERC721 nft;
        uint256 tokenId;
        bytes amount;
        uint256 bidTime;
        bool isWinner;
    }
    struct BidSatus {
        uint nftPostCounter;
        IERC721 nft;
        uint256 tokenId;
        bool isWinner;
    }

    struct NFT {
        uint postCounter;
        address postOwner;
        IERC721 nft;
        uint256 tokenId;
        uint256 endTime;
        uint256 bidConters;
    }
    // NFT
    mapping(uint => NFT) public postOwner;
    mapping(address => uint[]) public listPostCounter;
    mapping(address => mapping(IERC721 => mapping(uint256 => bool)))
        public isPostNFT;

    // BID
    mapping(uint => BidData) public bidOwner;
    mapping(address => uint[]) public listBidCounter;
    mapping(address => mapping(uint => bool)) public isBidNFT;

    // Mangger Highest Bid
    mapping(uint => address) public highestBidder;
    mapping(uint => euint32) public highestBidAmount;

    // Claim Status
    mapping(uint => address) public postOwnerClaimed;
    mapping(uint => address) public winnerClaimed;
    mapping(uint => mapping(address => bool)) public isLoserRefund;

    error TooEarly(uint256 time);

    error TooLate(uint256 time);

    event Winner(address who);

    constructor(
        EncryptedERC20 _paymentToken
    ) EIP712WithModifier("Authorization token", "1") {
        paymentToken = _paymentToken;
        owner = msg.sender;
        bidCounters = 0;
        postCounters = 0;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    modifier onlyBeforeEnd(uint _nftPostCounter) {
        if (block.timestamp >= postOwner[_nftPostCounter].endTime)
            revert TooLate(postOwner[_nftPostCounter].endTime);
        _;
    }

    modifier onlyAfterEnd(uint _nftPostCounter) {
        if (block.timestamp <= postOwner[_nftPostCounter].endTime)
            revert TooLate(postOwner[_nftPostCounter].endTime);
        _;
    }

    function setBidTokenId(
        IERC721 nft,
        uint256 tokenId,
        uint256 duration
    ) external {
        require(duration > 0, "Duration must be greater than 0");
        require(!isPostNFT[msg.sender][nft][tokenId], "NFT id already set");
        require(
            nft.ownerOf(tokenId) == msg.sender,
            "Your are not owner of this NFT"
        );
        nft.transferFrom(msg.sender, address(this), tokenId);
        isPostNFT[msg.sender][nft][tokenId] = true;
        postCounters++;
        listPostCounter[msg.sender].push(postCounters);
        postOwner[postCounters] = NFT({
            postCounter: postCounters,
            postOwner: msg.sender,
            nft: nft,
            tokenId: tokenId,
            endTime: block.timestamp + duration,
            bidConters: 0
        });
    }

    function bid(
        uint _nftPostCounter,
        bytes calldata encryptedValue
    ) public onlyBeforeEnd(_nftPostCounter) {
        require(
            postOwner[_nftPostCounter].postOwner != msg.sender,
            "Owner can't bid"
        );
        require(
            postOwner[_nftPostCounter].postOwner != address(0),
            "Invalid token id"
        );
        require(
            !isBidNFT[msg.sender][_nftPostCounter],
            "User already bid for this NFT"
        );
        // Save Bid info
        isBidNFT[msg.sender][_nftPostCounter] = true;
        euint32 value = TFHE.asEuint32(encryptedValue);
        bidCounters++;
        bidOwner[bidCounters] = BidData({
            nftPostCounter: _nftPostCounter,
            bidder: msg.sender,
            nft: postOwner[_nftPostCounter].nft,
            tokenId: postOwner[_nftPostCounter].tokenId,
            amount: value,
            bidTime: block.timestamp
        });
        listBidCounter[msg.sender].push(bidCounters);
        postOwner[_nftPostCounter].bidConters++;
        // Update Highest Bid
        euint32 currentHightestBid = highestBidAmount[_nftPostCounter];
        ebool isHigher = TFHE.lt(currentHightestBid, value);
        if (TFHE.decrypt(isHigher)) {
            highestBidAmount[_nftPostCounter] = value;
            highestBidder[_nftPostCounter] = msg.sender;
        }
        // Transfer bid token to contract
        paymentToken.transferFrom(msg.sender, address(this), value);
    }

    function claimAllNFT() external {
        // 1. Claim Post NFT not have bid
        NFT[] memory postNFTsEnded = listPostNFTEnded(msg.sender);
        euint32 totalBidAmount = TFHE.asEuint32(0);
        for (uint i = 0; i < postNFTsEnded.length; i++) {
            totalBidAmount = TFHE.add(
                totalBidAmount,
                highestBidAmount[postNFTsEnded[i].postCounter]
            );
            postOwnerClaimed[postNFTsEnded[i].postCounter] = msg.sender;
        }
        if (TFHE.decrypt(TFHE.gt(totalBidAmount, TFHE.asEuint32(0)))) {
            paymentToken.transfer(msg.sender, totalBidAmount);
        }

        // 2. Claim Winner NFT
        NFT[] memory winnerNFTs = listNFTBidAndWin(msg.sender);
        for (uint i = 0; i < winnerNFTs.length; i++) {
            winnerNFTs[i].nft.transferFrom(
                address(this),
                msg.sender,
                winnerNFTs[i].tokenId
            );
            isPostNFT[msg.sender][winnerNFTs[i].nft][
                winnerNFTs[i].tokenId
            ] = false;
            winnerClaimed[winnerNFTs[i].postCounter] = msg.sender;
        }

        // 3. Refund Not winner NFT
        NFT[] memory loserNFTs = listNFTBidAndLose(msg.sender);
        euint32 totalRefund = TFHE.asEuint32(0);
        for (uint i = 0; i < loserNFTs.length; i++) {
            totalRefund = TFHE.add(
                totalRefund,
                bidOwner[loserNFTs[i].postCounter].amount
            );
            isLoserRefund[loserNFTs[i].postCounter][msg.sender] = true;
        }
        if (TFHE.decrypt(TFHE.gt(totalRefund, TFHE.asEuint32(0)))) {
            paymentToken.transfer(msg.sender, totalRefund);
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
        uint[] memory _listPostCounter = listPostCounter[user];

        for (uint i = 0; i < _listPostCounter.length; i++) {
            if (isPostNFTEnded(user, _listPostCounter[i])) {
                count++;
            }
        }

        // Initialize the array with the correct size
        NFT[] memory nftList = new NFT[](count);
        uint index = 0;

        // Populate the array with valid NFTs
        for (uint i = 0; i < _listPostCounter.length; i++) {
            if (isPostNFTEnded(user, _listPostCounter[i])) {
                nftList[index] = postOwner[_listPostCounter[i]];
                index++;
            }
        }
        return nftList;
    }

    function listNFTBidAndWin(
        address user
    ) internal view returns (NFT[] memory) {
        uint[] memory _bidCounters = listBidCounter[user];
        uint count = 0;

        // First, count the number of NFTs the user has won
        for (uint i = 0; i < _bidCounters.length; i++) {
            if (
                isWinnerNFT(
                    _bidCounters[i],
                    bidOwner[_bidCounters[i]].nftPostCounter
                )
            ) {
                count++;
            }
        }

        // Initialize the array with the correct size
        NFT[] memory nftList = new NFT[](count);
        uint index = 0;

        // Populate the array with the NFTs the user has won
        for (uint i = 0; i < _bidCounters.length; i++) {
            if (
                isWinnerNFT(
                    _bidCounters[i],
                    bidOwner[_bidCounters[i]].nftPostCounter
                )
            ) {
                uint nftPostCounter = bidOwner[_bidCounters[i]].nftPostCounter;
                nftList[index] = postOwner[nftPostCounter];
                index++;
            }
        }

        return nftList;
    }

    function listNFTBidAndLose(
        address user
    ) internal view returns (NFT[] memory) {
        uint[] memory _bidCounters = listBidCounter[user];
        uint count = 0;

        // First, count the number of NFTs the user has lost
        for (uint i = 0; i < _bidCounters.length; i++) {
            if (
                isLoserNFT(
                    _bidCounters[i],
                    bidOwner[_bidCounters[i]].nftPostCounter
                )
            ) {
                count++;
            }
        }

        // Initialize the array with the correct size
        NFT[] memory nftList = new NFT[](count);
        uint index = 0;

        // Populate the array with the NFTs the user has lost
        for (uint i = 0; i < _bidCounters.length; i++) {
            if (
                isLoserNFT(
                    _bidCounters[i],
                    bidOwner[_bidCounters[i]].nftPostCounter
                )
            ) {
                uint nftPostCounter = bidOwner[_bidCounters[i]].nftPostCounter;
                nftList[index] = postOwner[nftPostCounter];
                index++;
            }
        }

        return nftList;
    }

    function isPostNFTEnded(
        address postAddress,
        uint _nftPostCounter
    ) internal view returns (bool) {
        return
            postOwner[_nftPostCounter].postOwner == postAddress &&
            highestBidder[_nftPostCounter] != address(0) &&
            postOwnerClaimed[_nftPostCounter] == address(0) &&
            isNFTBidEnded(_nftPostCounter);
    }

    function isWinnerNFT(
        uint _bidCounter,
        uint _nftPostCounter
    ) internal view returns (bool) {
        return
            highestBidder[_nftPostCounter] == bidOwner[_bidCounter].bidder &&
            winnerClaimed[_nftPostCounter] == address(0) &&
            isNFTBidEnded(_nftPostCounter);
    }

    function isLoserNFT(
        uint _bidCounter,
        uint _nftPostCounter
    ) internal view returns (bool) {
        return
            highestBidder[_nftPostCounter] != bidOwner[_bidCounter].bidder &&
            !isLoserRefund[_nftPostCounter][bidOwner[_bidCounter].bidder] &&
            isNFTBidEnded(_nftPostCounter);
    }

    function isNFTBidEnded(uint _nftPostCounter) internal view returns (bool) {
        return block.timestamp > postOwner[_nftPostCounter].endTime;
    }

    /**
     * Explorers
     */
    function exploreBidingNFT() external view returns (NFT[] memory) {
        uint count = 0;

        // First, count the number of valid NFTs
        for (uint i = 1; i <= postCounters; i++) {
            if (
                block.timestamp < postOwner[i].endTime &&
                postOwnerClaimed[i] == address(0)
            ) {
                count++;
            }
        }

        // Initialize the array with the correct size
        NFT[] memory nftList = new NFT[](count);
        uint index = 0;

        // Populate the array with valid NFTs
        for (uint i = 1; i <= postCounters; i++) {
            if (
                block.timestamp < postOwner[i].endTime &&
                winnerClaimed[i] == address(0)
            ) {
                nftList[index] = postOwner[i];
                index++;
            }
        }
        return nftList;
    }

    function exploreEndingNFT() external view returns (NFT[] memory) {
        uint count = 0;
        // First, count the number of ending NFTs
        for (uint i = 1; i <= postCounters; i++) {
            if (
                block.timestamp > postOwner[i].endTime &&
                winnerClaimed[i] == address(0)
            ) {
                count++;
            }
        }

        // Initialize the array with the correct size
        NFT[] memory nftList = new NFT[](count);
        uint index = 0;

        // Populate the array with ending NFTs
        for (uint i = 1; i <= postCounters; i++) {
            if (
                block.timestamp > postOwner[i].endTime &&
                winnerClaimed[i] == address(0)
            ) {
                nftList[index] = postOwner[i];
                index++;
            }
        }

        return nftList;
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
        uint[] memory _bidCounter = listBidCounter[msg.sender];
        BidDataStatus[] memory bidStatus = new BidDataStatus[](
            _bidCounter.length
        );
        for (uint i = 0; i < _bidCounter.length; i++) {
            BidData memory newBid = bidOwner[_bidCounter[i]];
            bytes memory amountEncode = TFHE.reencrypt(
                newBid.amount,
                publicKey
            );
            bidStatus[i] = BidDataStatus({
                nftPostCounter: newBid.nftPostCounter,
                bidder: newBid.bidder,
                nft: newBid.nft,
                tokenId: newBid.tokenId,
                amount: amountEncode,
                bidTime: newBid.bidTime,
                isWinner: highestBidder[newBid.nftPostCounter] == newBid.bidder
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
        BidData[] memory bids = listBidDataOfUser(msg.sender);
        uint count = countValidBids(bids);
        BidDataStatus[] memory bidStatus = new BidDataStatus[](count);
        populateBidStatus(bids, bidStatus, publicKey);
        return bidStatus;
    }

    function listBidDataOfUser(
        address user
    ) internal view returns (BidData[] memory) {
        uint[] memory _bidCounter = listBidCounter[user];
        BidData[] memory _bidData = new BidData[](_bidCounter.length);
        for (uint i = 0; i < _bidCounter.length; i++) {
            _bidData[i] = bidOwner[_bidCounter[i]];
        }
        return _bidData;
    }

    function countValidBids(
        BidData[] memory bids
    ) internal view returns (uint) {
        uint count = 0;
        for (uint i = 0; i < bids.length; i++) {
            if (block.timestamp < postOwner[bids[i].nftPostCounter].endTime) {
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
            if (block.timestamp < postOwner[newBid.nftPostCounter].endTime) {
                bytes memory amountEncode = TFHE.reencrypt(
                    newBid.amount,
                    publicKey
                );

                bidStatus[index] = BidDataStatus({
                    nftPostCounter: newBid.nftPostCounter,
                    bidder: newBid.bidder,
                    nft: newBid.nft,
                    tokenId: newBid.tokenId,
                    amount: amountEncode,
                    bidTime: newBid.bidTime,
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
        uint[] memory _listPostCounter = listPostCounter[msg.sender];
        // Count the number of NFTs owned by the sender
        uint count = 0;
        for (uint i = 0; i < _listPostCounter.length; i++) {
            NFT memory nft = postOwner[_listPostCounter[i]];
            if (winnerClaimed[nft.postCounter] == address(0)) {
                count++;
            }
        }
        // Initialize the array with the correct size
        NFT[] memory nftList = new NFT[](count);
        // Populate the array with valid NFTs
        uint index = 0;
        for (uint i = 0; i < _listPostCounter.length; i++) {
            NFT memory nft = postOwner[_listPostCounter[i]];
            if (winnerClaimed[nft.postCounter] == address(0)) {
                nftList[index] = nft;
                index++;
            }
        }
        return nftList;
    }

    // Bid status

    function getBidsStatusOfAddress(
        address user
    ) internal view returns (BidSatus[] memory) {
        uint[] memory _bidCounter = listBidCounter[user];
        BidSatus[] memory _bidStatus = new BidSatus[](_bidCounter.length);
        for (uint i = 0; i < _bidCounter.length; i++) {
            BidData memory newBid = bidOwner[_bidCounter[i]];
            bool isWinner = highestBidder[newBid.nftPostCounter] == user &&
                block.timestamp > postOwner[newBid.nftPostCounter].endTime;
            _bidStatus[i] = BidSatus({
                nftPostCounter: newBid.nftPostCounter,
                nft: newBid.nft,
                tokenId: newBid.tokenId,
                isWinner: isWinner
            });
        }
        return _bidStatus;
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
