// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {USDTest} from "./USDTest.sol";

/**
 * @title HundredDollarAuction
 * @author Vermont Phil Paguiligan
 *
 * Terms:
 * Auctioneer - entity who opens and has the authority to end and cancel the auction
 * Bidder - the user who joins the auction
 * Winning Bid - the highest standing bid amount when the auction ends
 * Losing Bid - the lowest standing bid amount when the auction ends
 * 
 * BUY MY $100 FOR ONLY $1.
 * 
 * @notice This contract holds 100 USDTest which can be bought for at least 1 USDTest.
 * 
 * But here's the catch:
 * 
 * 1. There should be 2 bidders to compete.
 * 2. The other bidder should forfeit or the auctioneer ends the auction with your winning
 *    bid for you to win.
 * 3. When the auction ends, the winning and losing bid will be collected by this contract.
 *    And the price of $100 will be given to the highest bidder.
 * 4. When either of the bid reaches $100, the auctioneer can end the
 *    auction anytime.
 */
contract HundredDollarAuction {
    error HundredDollarAuction__TransferFailed();
    error HundredDollarAuction__BidCollectionFailed();
    error HundredDollarAuction__BiddersOccupied();
    error HundredDollarAuction__AuctioneerOccupied();
    error HundredDollarAuction__AmountDidNotOutbid();
    error HundredDollarAuction__NotABidder();
    error HundredDollarAuction__NotAnAuctioneer();
    error HundredDollarAuction__LessThanTwoBidders();
    error HundredDollarAuction__TheSameBidderNotAllowed();
    error HundredDollarAuction__BidderCantOverseeAuction();

    enum Status { WAITING, ACTIVE, CAN_COLLECT, ENDED, CANCELLED }

    uint256 private constant AUCTION_PRICE = 100e18;
    uint256 private constant INITIAL_BID_AMOUNT = 1e18;

    mapping(address bidder => uint256 bidAmount) private s_bidAmounts;
    // This mapping makes toggling between bidders easier and more gas efficient
    // instead of finding bidder and opponent bidder everytime.
    mapping(address bidder => address opponentBidder) private s_opponentBidder;

    address private s_factory;
    address private s_auctioneer;
    address private s_firstBidder;
    address private s_secondBidder;
    address private s_winningBidder;
    Status private s_status = Status.WAITING;
    USDTest private immutable i_usdt;

    /**
     * @param usdt the token to bid and to be given as a reward
     * @param auctioneer the entity who oversees the auction
     * 
     * Role of the auctioneer:
     * 1. End the auction when either of the bid gets $100 of more.
     * 2. Cancel the auction if it is idle for a given time.
     * 
     * Auctioneer will get a 10% commission based on the auction profit.
     * We will need a deposit of $10 from auctioneer. It will be returned
     * after the auction has ended or cancelled
     * 
     * Example:
     * auctionPrice = $100
     * winningBid = $110
     * losingBid = $90
     * 
     * collectedBids = winningBid + losingBid // $110 + $90 = $200
     * 
     * profit = collectedBids - auctionPrice // $200 - $100 = $100
     * 
     * commission = profit * 10% // $100 * 10% = $10
     */
    constructor(USDTest usdt, address auctioneer) {
        s_factory = msg.sender;
        i_usdt = usdt;
        s_auctioneer = auctioneer;
        // s_bidAmounts[s_firstBidder] = INITIAL_BID_AMOUNT;
    }

    modifier onlyBidder {
        if (msg.sender != s_firstBidder || msg.sender != s_secondBidder) {
            revert HundredDollarAuction__NotABidder();
        }
        _;
    }

    modifier onlyWithTwoBidders {
        if (s_secondBidder == address(0)) {
            revert HundredDollarAuction__LessThanTwoBidders();
        }
        _;
    }

    modifier onlyAuctioneer {
        if (msg.sender != s_auctioneer) {
            revert HundredDollarAuction__NotAnAuctioneer();
        }
        _;
    }

    function joinAuction(uint256 bidAmount) public {
        if (s_secondBidder != address(0)) {
            revert HundredDollarAuction__BiddersOccupied();
        }
        if (bidAmount <= INITIAL_BID_AMOUNT) {
            revert HundredDollarAuction__AmountDidNotOutbid();
        }
        if (s_firstBidder == msg.sender) {
            revert HundredDollarAuction__TheSameBidderNotAllowed();
        }

        s_secondBidder = msg.sender;
        s_bidAmounts[s_secondBidder] = INITIAL_BID_AMOUNT;
        s_status = Status.ACTIVE;

        s_opponentBidder[s_firstBidder] = s_secondBidder;
        s_opponentBidder[s_secondBidder] = s_firstBidder;
        _updateWinningBidder();
    }

    function outBid(uint256 bidIncrement) public onlyBidder onlyWithTwoBidders {
        uint256 currentBid = s_bidAmounts[msg.sender] + bidIncrement;
        if (currentBid <= s_bidAmounts[s_opponentBidder[msg.sender]]) {
            revert HundredDollarAuction__AmountDidNotOutbid();
        }

        s_bidAmounts[msg.sender] = currentBid;
        _updateWinningBidder();
    }

    function forfeit() public onlyBidder onlyWithTwoBidders {
        _endAuction(s_opponentBidder[msg.sender]);
    }

    // block.timestamp safe with 15-second rule
    function cancelAuction() public onlyAuctioneer {}

    function overseeAuction() public {
        if (s_auctioneer != address(0)) {
            revert HundredDollarAuction__AuctioneerOccupied();
        }
        if (msg.sender == s_firstBidder || msg.sender == s_secondBidder) {
            revert HundredDollarAuction__BidderCantOverseeAuction();
        }

        s_auctioneer = msg.sender;
    }

    function endAuction() public onlyAuctioneer {
        _endAuction(s_winningBidder);
    }

    function _endAuction(address winner) private {
        bool transferedToWinner = i_usdt.transfer(winner, AUCTION_PRICE);
        if (!transferedToWinner) {
            revert HundredDollarAuction__TransferFailed();
        }

        bool collectedBids = i_usdt.transfer(s_factory, i_usdt.balanceOf(address(this)));
        if (!collectedBids) {
            revert HundredDollarAuction__BidCollectionFailed();
        }

        s_status = Status.ENDED;
    }

    function _updateWinningBidder() private {
        s_winningBidder = msg.sender;

        if (s_bidAmounts[s_winningBidder] >= AUCTION_PRICE) {
            s_status = Status.CAN_COLLECT;
        }
    }

    function _getStatus() private view returns (Status) {
        return s_status;
    }
}
