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
    /////////////////
    // Errors      //
    /////////////////
    error HundredDollarAuction__TransferFailed();
    error HundredDollarAuction__BidCollectionFailed();
    error HundredDollarAuction__BiddersOccupied();
    error HundredDollarAuction__AuctioneerOccupied();
    error HundredDollarAuction__AmountDidNotOutbid(uint256 currentBid, uint256 amountToBid);
    error HundredDollarAuction__BelowMinimumBidAmount(uint256 amountToBid);
    error HundredDollarAuction__NotABidder();
    error HundredDollarAuction__NotAnAuctioneer();
    error HundredDollarAuction__LessThanTwoBidders();
    error HundredDollarAuction__TheSameBidderNotAllowed();
    error HundredDollarAuction__BidderCantOverseeAuction();
    error HundredDollarAuction__AuctioneerCannotJoinAsBidder();
    error HundredDollarAuction__AuctionNotYetIdle();

    ////////////////
    // Enums      //
    ////////////////
    enum Status { OPEN, WAITING, ACTIVE, CAN_COLLECT, ENDED, CANCELLED }
    enum NumberOfBidders { ZERO, ONE, TWO }

    //////////////////////////
    // State Variables      //
    //////////////////////////
    uint256 private constant AUCTION_PRICE = 100e18;
    uint256 private constant MINIMUM_BID_AMOUNT = 1e18;
    uint256 private constant AMOUNT_DEPOSIT = 10e18;
    uint256 private constant MIN_WAITING_TIME = 10800; // 3 hours minimum waiting time before the auction gets cancelled
    uint256 private constant FACTORY_COLLECTION_THRESHOLD = 80;
    uint256 private constant REWARD_THRESHOLD = 10;
    uint256 private constant PRECISION = 100;

    mapping(address bidder => uint256 bidAmount) private s_bidAmounts;
    // This mapping makes toggling between bidders easier and more gas efficient
    // instead of finding bidder and opponent bidder everytime.
    mapping(address bidder => address opponentBidder) private s_opponentBidder;

    address private s_auctioneer;
    address private s_firstBidder;
    address private s_secondBidder;
    address private s_winningBidder;
    uint256 private s_currentBid;
    uint256 private s_latestTimestamp;
    NumberOfBidders private s_numberOfBidders = NumberOfBidders.ZERO;
    Status private s_status = Status.OPEN;
    address private immutable i_factory;
    USDTest private immutable i_usdt;

    ////////////////////
    // Functions      //
    ////////////////////

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
        i_factory = msg.sender;
        i_usdt = usdt;
        s_auctioneer = auctioneer;
        // block.timestamp safe with 15-second rule
        s_latestTimestamp = block.timestamp;
    }


    ////////////////////
    // Modifiers      //
    ////////////////////

    modifier onlyBidder {
        if (msg.sender != s_firstBidder || msg.sender != s_secondBidder) {
            revert HundredDollarAuction__NotABidder();
        }
        _;
    }

    modifier onlyWithTwoBidders {
        if (s_numberOfBidders != NumberOfBidders.TWO) {
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

    modifier bidAmountChecked(uint256 amountToBid) {
        // minimum amount should be $1
        if (amountToBid < MINIMUM_BID_AMOUNT) {
            revert HundredDollarAuction__BelowMinimumBidAmount(amountToBid);
        }
        _;
    }

    ///////////////////////////
    // Public Functions      //
    ///////////////////////////

    /**
     * @param amountToBid the amount user is willing to bid for $100
     * 
     * @notice only two bidders can join the auction for this to become active
     * meaning this function can only be called successfully twice in its entirety
     */
    function joinAuction(uint256 amountToBid) public bidAmountChecked(amountToBid) {
        if (msg.sender == s_auctioneer) {
            revert HundredDollarAuction__AuctioneerCannotJoinAsBidder();
        }

        if (s_firstBidder == address(0)) {
            _joinAuctionAsFirstBidder(amountToBid);
        }
        else {
            _joinAuctionAsSecondBidder(amountToBid);
        }
    }

    /**
     * @param bidIncrement how much the bidder will increase their bid
     * @notice outbid your opponent to win the $100 price!!
     */
    function outbid(uint256 bidIncrement) public onlyBidder onlyWithTwoBidders bidAmountChecked(bidIncrement) {
        uint256 amountToBid = s_bidAmounts[msg.sender] + bidIncrement;

        // lower bid than the current is not valid
        if (amountToBid <= s_bidAmounts[s_opponentBidder[msg.sender]]) {
            revert HundredDollarAuction__AmountDidNotOutbid(s_currentBid, amountToBid);
        }

        s_bidAmounts[msg.sender] = amountToBid;
        _collectFromBidder(amountToBid);
        _updateCurrentBidAndWinningBidder(amountToBid);
    }

    /**
     * You may not have enough USDTest to outbid the opponent anymore.
     * Since it's not all about winning, call this function if you want to avoid further loses :)
     * 
     * @notice calling this function will make opponent the winner by default.
     */
    function forfeit() public onlyBidder onlyWithTwoBidders {
        _endAuction(s_opponentBidder[msg.sender]);
    }

    /**
     * When the auction becomes idle, the auctioneer can choose to cancel the auction anytime.
     */
    function cancelAuction() public onlyAuctioneer {
        if (!_isIdle()) {
            revert HundredDollarAuction__AuctionNotYetIdle();
        }

        NumberOfBidders numberOfBidders = s_numberOfBidders;
        address firstBidder = s_firstBidder;
        if (numberOfBidders == NumberOfBidders.ZERO) {
            // when the auction doesn't get any bidder
            _returnDepositAndFunds();
        }
        else if (numberOfBidders == NumberOfBidders.ONE) {
            // when the auction doesn't get a second bidder
            _returnDepositAndFunds();

            // refund first bidder
            _transferUsdt(firstBidder, s_bidAmounts[s_firstBidder]);
        }
        else {
            // punish the bidder who becomes idle, idle bidder's bid will be taken and divided by this contract:
            uint256 amountTaken = s_bidAmounts[s_opponentBidder[s_winningBidder]];
            // 80% will be collected by auction factory
            uint256 amountToCollect = amountTaken * FACTORY_COLLECTION_THRESHOLD / PRECISION;
            // 10% to reward the auctioneer
            // 10% to reward the other bidder
            uint256 amountToReward = amountTaken * REWARD_THRESHOLD / PRECISION;

            // retrieve auction price with amount taken
            _transferUsdt(i_factory, AUCTION_PRICE + amountToCollect);

            // refund auctioneer and winning bidder with rewards
            _transferUsdt(s_auctioneer, AMOUNT_DEPOSIT + amountToReward);
            _transferUsdt(s_winningBidder, s_bidAmounts[s_winningBidder] + amountToReward);
        }
        s_status = Status.CANCELLED;
    }

    function endAuction() public onlyAuctioneer {
        _endAuction(s_winningBidder);
    }

    ////////////////////////////
    // Private Functions      //
    ////////////////////////////

    /**
     * @param amountToBid the amount set by first bidder which should be more than or equal to MINIMUM_BID_AMOUNT ($1).
     * @notice the bidder will occupy the s_firstBidder slot
     */
    function _joinAuctionAsFirstBidder(uint256 amountToBid) private {
        // minimum amount should be $1
        if (amountToBid < MINIMUM_BID_AMOUNT) {
            revert HundredDollarAuction__BelowMinimumBidAmount(amountToBid);
        }

        s_firstBidder = msg.sender;
        s_bidAmounts[s_firstBidder] = amountToBid;
        s_numberOfBidders = NumberOfBidders.ONE;
        s_status = Status.WAITING;
        _collectFromBidder(amountToBid);
        _updateCurrentBid(amountToBid);
    }

    /**
     * @param amountToBid the amount set by second bidder which should be more than the bid of first bidder.
     * @notice the bidder will occupy the s_secondBidder slot
     */
    function _joinAuctionAsSecondBidder(uint256 amountToBid) private {
        // only to bidders should be able to enter this auction
        if (s_secondBidder != address(0)) {
            revert HundredDollarAuction__BiddersOccupied();
        }
        // should outbid the first bidder
        if (amountToBid <= s_bidAmounts[s_firstBidder]) {
            revert HundredDollarAuction__AmountDidNotOutbid(s_currentBid, amountToBid);
        }
        // make this auction more fun! two bidders should be different :)
        if (s_firstBidder == msg.sender) {
            revert HundredDollarAuction__TheSameBidderNotAllowed();
        }

        s_secondBidder = msg.sender;
        s_bidAmounts[s_secondBidder] = MINIMUM_BID_AMOUNT;
        s_status = Status.ACTIVE;
        s_numberOfBidders = NumberOfBidders.TWO;

        s_opponentBidder[s_firstBidder] = s_secondBidder;
        s_opponentBidder[s_secondBidder] = s_firstBidder;
        _collectFromBidder(amountToBid);
        _updateCurrentBidAndWinningBidder(amountToBid);
    }

    // when the auction gets cancelled,
    function _returnDepositAndFunds() private {
        // return the deposit of auctioneer
        _transferUsdt(s_auctioneer, AMOUNT_DEPOSIT);
        // return the funds to auction factory
        _transferUsdt(i_factory, AUCTION_PRICE);
    }

    function _transferUsdt(address to, uint256 amount) private {
        bool success = i_usdt.transfer(to, amount);
        if (!success) {
            revert HundredDollarAuction__TransferFailed();
        }
    }

    function _collectFromBidder(uint256 amountToBid) private {
        bool success = i_usdt.transferFrom(msg.sender, address(this), amountToBid);
        if (!success) {
            revert HundredDollarAuction__TransferFailed();
        }
    }

    function _endAuction(address winner) private {
        uint256 totalBids = _totalBids();
        // reward the auctioneer based on the auction gains
        int256 auctionGain = int256(totalBids - AUCTION_PRICE);
        uint256 auctioneerReward;
        if (auctionGain > 0) {
            auctioneerReward = uint256(auctionGain) * REWARD_THRESHOLD / PRECISION;
        }
        // amount to return to factory
        uint256 retrieveAmount = totalBids - auctioneerReward;

        _transferUsdt(i_factory, retrieveAmount);
        _transferUsdt(s_auctioneer, AMOUNT_DEPOSIT + auctioneerReward);
        _transferUsdt(winner, AUCTION_PRICE);

        s_status = Status.ENDED;
    }

    function _updateCurrentBid(uint256 amountToBid) private {
        s_currentBid = amountToBid;
    }

    function _updateWinningBidder() private {
        s_winningBidder = msg.sender;

        if (s_currentBid >= AUCTION_PRICE) {
            s_status = Status.CAN_COLLECT;
        }
    }

    function _updateCurrentBidAndWinningBidder(uint256 amountToBid) private {
        _updateCurrentBid(amountToBid);
        _updateWinningBidder();
    }

    /////////////////////////////////
    // Private View Functions      //
    /////////////////////////////////

    function _idleTime() private view returns (uint256) {
        return block.timestamp - s_latestTimestamp;
    }

    function _isIdle() private view returns (bool) {
        return _idleTime() > MIN_WAITING_TIME;
    }

    function _totalBids() private view returns (uint256) {
        return s_bidAmounts[s_firstBidder] + s_bidAmounts[s_secondBidder];
    }

    ////////////////////////////////
    // Public View Functions      //
    ////////////////////////////////

    function getStatus() public view returns (Status) {
        return s_status;
    }

    function getNumberOfBidders() public view returns (NumberOfBidders) {
        return s_numberOfBidders;
    }

    function getIdleTime() public view returns (uint256) {
        return _idleTime();
    }

    function getIsIdle() public view returns (bool) {
        return _isIdle();
    }
}
