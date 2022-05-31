// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.12;

import "./ERC721Validator.sol";
import "./Loyalty.sol";
import "./FeeManager.sol";

import "./interfaces/IMoonraySingleExchange.sol";
import "./interfaces/IERC721Receiver.sol";

import "./libraries/MoonrayLibrary.sol";
import "./libraries/TransferHelper.sol";

/// @title Moonray Exchange ERC721 token contract
/// @notice Moonray Exchanger for single NFTs
contract MoonraySingleExchange is
    ERC721Validator,
    IMoonraySingleExchange,
    Loyalty,
    FeeManager
{
    // @dev Used to put NFT in sell by holder's address and assetId
    mapping(address => mapping(uint256 => Offer)) public offers;
    // For auctions bid by bider, collection and assetId
    mapping(address => mapping(uint256 => mapping(address => Bid)))
        public bidforAuctions;

    modifier onlyOfferOwner(address collection, uint256 assetId) {
        require(_msgSender() == offers[collection][assetId].seller);
        _;
    }

    function addLoyaltyOffer(
        address _seller,
        address _collection,
        uint256 _assetId,
        address token,
        uint256 _price,
        bool isForSell,
        bool isForAuction,
        uint256 expiresAt,
        uint256 shareIndex,
        uint256 loyaltyPercent
    ) external {
        addLoyalty(_collection, _assetId, _msgSender(), loyaltyPercent);
        _addOffer(
            _seller,
            _collection,
            _assetId,
            token,
            _price,
            isForSell,
            isForAuction,
            expiresAt,
            shareIndex
        );
    }

    function addOffer(
        address _seller,
        address _collection,
        uint256 _assetId,
        address token,
        uint256 _price,
        bool isForSell,
        bool isForAuction,
        uint256 expiresAt,
        uint256 shareIndex
    ) external {
        _addOffer(
            _seller,
            _collection,
            _assetId,
            token,
            _price,
            isForSell,
            isForAuction,
            expiresAt,
            shareIndex
        );
    }

    function _addOffer(
        address _seller,
        address _collection,
        uint256 _assetId,
        address token,
        uint256 _price,
        bool isForSell,
        bool isForAuction,
        uint256 expiresAt,
        uint256 shareIndex
    ) internal {
        require(!offers[_collection][_assetId].exists, "Offer exists already");
        // get NFT asset from seller
        IERC721 singleNFTCollection = _requireERC721(_collection);
        require(
            singleNFTCollection.ownerOf(_assetId) == _msgSender(),
            "Transfer caller is not owner"
        );

        require(_seller == _msgSender(), "Seller should be equals owner");
        require(
            singleNFTCollection.isApprovedForAll(_msgSender(), address(this)),
            "Contract not approved"
        );
        offers[_collection][_assetId] = Offer(
            _seller,
            _collection,
            _assetId,
            token,
            _price,
            isForSell,
            isForAuction,
            expiresAt,
            shareIndex,
            true // offer exists
        );
        singleNFTCollection.safeTransferFrom(_seller, address(this), _assetId);
        emit Listed(_seller, _collection, _assetId, token, _price);
    }

    function setOfferPrice(
        address collection,
        uint256 assetId,
        uint256 price
    ) external {
        Offer storage offer = _getOwnerOffer(collection, assetId);
        offer.price = price;
        emit SetOfferPrice(collection, assetId, price);
    }

    function setForSell(
        address collection,
        uint256 assetId,
        bool isForSell
    ) external {
        Offer storage offer = _getOwnerOffer(collection, assetId);
        offer.isForSell = isForSell;
        emit SetForSell(collection, assetId, isForSell);
    }

    function setForAuction(
        address collection,
        uint256 assetId,
        bool isForAuction
    ) external {
        Offer storage offer = _getOwnerOffer(collection, assetId);
        offer.isForAuction = isForAuction;
        emit SetForAuction(collection, assetId, isForAuction);
    }

    function setExpiresAt(
        address collection,
        uint256 assetId,
        uint256 expiresAt
    ) external onlyOfferOwner(collection, assetId) {
        Offer storage offer = _getOwnerOffer(collection, assetId);
        offer.expiresAt = expiresAt;
        emit SetExpireAt(collection, assetId, expiresAt);
    }

    function cancelOffer(address collection, uint256 assetId)
        external
        onlyOfferOwner(collection, assetId)
    {
        Offer memory offer = _getOwnerOffer(collection, assetId);
        IERC721 singleNFTCollection = _requireERC721(collection);
        require(_msgSender() == offer.seller, "Marketpalce: invalid owner");
        require(offer.expiresAt < block.timestamp, "Offer should be expired");
        delete offers[collection][assetId];
        singleNFTCollection.safeTransferFrom(
            address(this),
            offer.seller,
            offer.assetId
        );
        emit CancelOffer(collection, assetId);
    }

    function _getOwnerOffer(address collection, uint256 assetId)
        internal
        view
        returns (Offer storage)
    {
        Offer storage offer = offers[collection][assetId];
        return offer;
    }

    function buyOffer(address collection, uint256 assetId) external payable {
        Offer memory offer = offers[collection][assetId];
        require(msg.value > 0, "price must be >0");
        require(offer.isForSell, "Offer not for sell");
        require(
            offer.expiresAt > block.timestamp,
            "Marketplace: offer expired"
        );
        _buyOffer(offer);
        emit Swapped(
            _msgSender(),
            offer.seller,
            collection,
            assetId,
            msg.value
        );
    }

    function _buyOffer(Offer memory offer) internal {
        IERC721 singleNFTCollection = _requireERC721(offer.collection);
        (uint256 ownerProfitAmount, uint256 sellerAmount) = MoonrayLibrary
            .computePlateformOwnerProfit(
                offer.price,
                msg.value,
                getFeebyIndex(offer.shareIndex)
            );
        require(
            offer.price <= sellerAmount,
            "price should equal or upper to offer price"
        );
        sellerAmount = sendLoyaltyToCreatorFromETH(
            offer.collection,
            offer.assetId,
            offer.seller,
            sellerAmount
        );
        TransferHelper.safeTransferETH(offer.seller, sellerAmount);
        TransferHelper.safeTransferETH(owner(), ownerProfitAmount);
        delete offers[offer.collection][offer.assetId];
        singleNFTCollection.transferFrom(
            address(this),
            _msgSender(),
            offer.assetId
        );
    }

    function safePlaceBid(
        address _collection,
        uint256 _assetId,
        address _token,
        uint256 _price
    ) public {
        _createBid(_collection, _assetId, _token, _price);
    }

    function _createBid(
        address _collection,
        uint256 _assetId,
        address _token,
        uint256 _price
    ) internal {
        // Checks order validity
        Offer memory offer = offers[_collection][_assetId];
        // check on expire time
        // Check price if theres previous a bid
        Bid memory bid = bidforAuctions[_collection][_assetId][_msgSender()];
        require(bid.bidder != _msgSender());
        require(_token == offer.token);
        require(_msgSender() != offer.seller, "owner could not place bid");
        require(offer.isForAuction, "NFT Marketplace: NFT token not in sell");
        require(
            offer.expiresAt > block.timestamp,
            "Marketplace: offer expired"
        );
        require(
            IERC20(_token).allowance(_msgSender(), address(this)) >= _price,
            "NFT Marketplace: Allowance error"
        );
        // Create bid
        bytes32 bidId = keccak256(
            abi.encodePacked(block.timestamp, msg.sender, _price)
        );

        // Save Bid for this order
        bidforAuctions[_collection][_assetId][_msgSender()] = Bid({
            id: bidId,
            bidder: _msgSender(),
            token: _token,
            price: _price
        });

        emit BidCreated(
            bidId,
            _collection,
            _assetId,
            _msgSender(), // bidder
            _token,
            _price
        );
    }

    function cancelBid(
        address _collection,
        uint256 _assetId,
        address _bidder
    ) external {
        IERC721 singleNFTCollection = _requireERC721(_collection);
        require(
            _bidder == _msgSender() ||
                _msgSender() == singleNFTCollection.ownerOf(_assetId),
            "Marketplace: Unauthorized operation"
        );
        Bid memory bid = bidforAuctions[_collection][_assetId][_msgSender()];
        delete bidforAuctions[_collection][_assetId][_bidder];
        emit BidCancelled(bid.id);
    }

    function acceptBid(
        address _collection,
        uint256 _assetId,
        address _bidder
    ) external {
        //get offer
        Offer memory offer = offers[_collection][_assetId];
        // get bid to accept
        Bid memory bid = bidforAuctions[_collection][_assetId][_bidder];
        require(
            offer.seller == _msgSender(),
            "Marketplace: unauthorized sender"
        );
        require(offer.isForAuction, "Marketplace: offer not in auction");
        // get service fees
        (uint256 ownerProfitAmount, uint256 sellerAmount) = MoonrayLibrary
            .computePlateformOwnerProfit(
                bid.price,
                bid.price,
                getFeebyIndex(offer.shareIndex)
            );
        sellerAmount = sendLoyaltyToCreatorFromETH(
            offer.collection,
            offer.assetId,
            offer.seller,
            sellerAmount
        );
        // check seller
        delete bidforAuctions[_collection][_assetId][_bidder];
        emit BidAccepted(bid.id);

        // transfer escrowed bid amount minus market fee to seller
        IERC20(bid.token).transferFrom(bid.bidder, _msgSender(), sellerAmount);
        IERC20(bid.token).transferFrom(bid.bidder, owner(), ownerProfitAmount);

        delete offers[_collection][_assetId];
        // Transfer NFT asset
        IERC721(_collection).safeTransferFrom(
            address(this),
            bid.bidder,
            _assetId
        );
        // Notify ..
        emit BidSuccessful(
            _collection,
            _assetId,
            bid.token,
            bid.bidder,
            bid.price
        );
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
