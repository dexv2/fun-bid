// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {USDTest} from "./USDTest.sol";
import {HundredDollarAuction} from "./HundredDollarAuction.sol";

/**
 * @title BiddingFactory
 * @author Vermont Phil Paguiligan
 * @notice This contract creates an Auction contract which is initiated by a user who wants to enter the auction.
 * This also funds the Auction contract by 100 USDTest upon creation which should be the price of the user who wins the bid.
 */
contract BiddingFactory {
    error BiddingFactory__TransferFailed();
    error BiddingFactory__MintFailed();

    uint256 private constant AUCTION_PRICE = 100e18;
    uint256 private constant INITIAL_BID_AMOUNT = 1e18;

    address[] private auctionList;
    USDTest private immutable i_usdt;

    event HundredDollarAuctionCreated(address indexed Auction);

    constructor(USDTest usdt) {
        i_usdt = usdt;
    }

    /**
     * This is the main function of the Bidding factory which creates the Auction contract.
     * Upon starting the bid, the user pays 1 USDTest as an initial bid amount.
     */
    function startBid() public {
        HundredDollarAuction auction = new HundredDollarAuction(i_usdt, msg.sender);
        auctionList.push(address(auction));

        bool success = i_usdt.transferFrom(msg.sender, address(auction), INITIAL_BID_AMOUNT);
        if (!success) {
            revert BiddingFactory__TransferFailed();
        }

        /**
         * The Auction contract gets a fund for the winning bid.
         */
        bool minted = i_usdt.mint(address(auction), AUCTION_PRICE);
        if (!minted) {
            revert BiddingFactory__MintFailed();
        }

        emit HundredDollarAuctionCreated(address(auction));
    }
}
