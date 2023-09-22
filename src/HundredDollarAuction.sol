// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {USDT} from "./USDT.sol";

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
 * @notice This contract holds 100 USDT which can be bought for at least 1 USDT.
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
    error HundredDollarAuction__BiddersOccupied();
    error HundredDollarAuction__AmountDidNotOutbid(uint256 currentBid, uint256 amountToBid);
    error HundredDollarAuction__BelowMinimumBidAmount(uint256 amountToBid);
    error HundredDollarAuction__NotABidder();
    error HundredDollarAuction__NotAnAuctioneer();
    error HundredDollarAuction__TheSameBidderNotAllowed();
    error HundredDollarAuction__AuctioneerCannotJoinAsBidder();
    error HundredDollarAuction__AuctionNotYetIdle();
    error HundredDollarAuction__CantEndWhenBidDoesntReachAuctionPrice();
    error HundredDollarAuction__FunctionCalledAtIncorrectState(State currentState, State functionState);
    error HundredDollarAuction__AuctionAlreadyEnded();
    error HundredDollarAuction__NoOutstandingAmountWithdrawable();
    error HundredDollarAuction__NotEOA();

    /////////////////
    // Events      //
    /////////////////
    event BidAdded(
        address indexed auction,
        address indexed bidder,
        address indexed opponentBidder,
        uint256 amountBid
    );
    event AuctionEnded(
        address indexed auction,
        address indexed winningBidder,
        address indexed auctioneer,
        address losingBidder,
        uint256 winningBid,
        uint256 losingBid,
        uint256 totalBids
    );
    event AuctionCancelled(
        address indexed auction,
        address indexed auctioneer,
        uint256 amountCollected
    );

    ////////////////
    // Enums      //
    ////////////////
    enum State { OPEN, ACTIVE, ENDED }
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
    mapping(address bidder => uint256 amountWithdrawable) private s_amountWithdrawable;

    address private s_auctioneer;
    address private s_firstBidder;
    address private s_secondBidder;
    address private s_winningBidder;
    uint256 private s_currentBid;
    uint256 private s_latestTimestamp;
    NumberOfBidders private s_numberOfBidders;
    State private s_state;
    address private immutable i_factory;
    USDT private immutable i_usdt;

    ////////////////////
    // Functions      //
    ////////////////////

    /**
     * @param usdt the token to bid and to be given as a reward
     * @param auctioneer the entity who oversees the auction
     * 
     * Role of the auctioneer:
     * 1. End the auction when either of the bid gets $100 or more.
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
    constructor(USDT usdt, address auctioneer) {
        i_factory = msg.sender;
        i_usdt = usdt;
        s_auctioneer = auctioneer;
        // block.timestamp safe with 15-second rule
        s_latestTimestamp = block.timestamp;
        s_numberOfBidders = NumberOfBidders.ZERO;
        s_state = State.OPEN;
    }

    ////////////////////
    // Modifiers      //
    ////////////////////

    modifier onlyBidder {
        if (msg.sender != s_firstBidder && msg.sender != s_secondBidder) {
            revert HundredDollarAuction__NotABidder();
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

    modifier atState(State state) {
        if (s_state != state) {
            revert HundredDollarAuction__FunctionCalledAtIncorrectState(s_state, state);
        }
        _;
    }

    /////////////////////////////
    // External Functions      //
    /////////////////////////////

    /**
     * @param amountToBid the amount user is willing to bid for $100
     * 
     * @notice only two bidders can join the auction for this to become active
     * meaning this function can only be called successfully twice in its entirety
     */
    function joinAuction(uint256 amountToBid)
        external
        atState(State.OPEN)
        bidAmountChecked(amountToBid)
    {
        if (msg.sender != tx.origin) {
            revert HundredDollarAuction__NotEOA();
        }

        if (msg.sender == s_auctioneer) {
            revert HundredDollarAuction__AuctioneerCannotJoinAsBidder();
        }

        if (s_firstBidder == address(0)) {
            _joinAuctionAsFirstBidder(amountToBid);
        }
        else {
            _joinAuctionAsSecondBidder(amountToBid);
        }

        _updateTimestamp();

        emit BidAdded(address(this), msg.sender, s_opponentBidder[msg.sender], amountToBid);
    }

    /**
     * @param bidIncrement how much you would want to increase your bid
     * @notice outbid your opponent to win the $100 price!!
     */
    function outbid(uint256 bidIncrement)
        external
        onlyBidder
        atState(State.ACTIVE)
        bidAmountChecked(bidIncrement)
    {
        uint256 amountToBid = s_bidAmounts[msg.sender] + bidIncrement;

        // lower bid than the current is not valid
        if (amountToBid <= s_bidAmounts[s_opponentBidder[msg.sender]]) {
            revert HundredDollarAuction__AmountDidNotOutbid(s_currentBid, amountToBid);
        }

        s_bidAmounts[msg.sender] = amountToBid;
        _collectFromBidder(bidIncrement);
        _updateCurrentBidAndWinningBidder(amountToBid);

        _updateTimestamp();

        emit BidAdded(address(this), msg.sender, s_opponentBidder[msg.sender], amountToBid);
    }

    /**
     * @notice calling this function will make opponent the winner by default.
     */
    function forfeit()
        external
        onlyBidder
        atState(State.ACTIVE)
    {
        _endAuction(s_opponentBidder[msg.sender]);
    }

    /**
     * When the auction becomes idle, the auctioneer can choose
     * to cancel the auction at any states, except State.ENDED
     */
    function cancelAuction()
        external
        onlyAuctioneer
    {
        if (!_isIdle()) {
            revert HundredDollarAuction__AuctionNotYetIdle();
        }
        if (s_state == State.ENDED) {
            revert HundredDollarAuction__AuctionAlreadyEnded();
        }

        address auctioneer = s_auctioneer;
        uint256 amountRetrieved = AUCTION_PRICE;
        NumberOfBidders numberOfBidders = s_numberOfBidders;

        if (numberOfBidders == NumberOfBidders.ZERO) {
            // when the auction doesn't get any bidder
            _returnDepositAndFunds(AUCTION_PRICE, AMOUNT_DEPOSIT);
        }
        else if (numberOfBidders == NumberOfBidders.ONE) {
            address firstBidder = s_firstBidder;
            // when the auction doesn't get a second bidder
            _returnDepositAndFunds(AUCTION_PRICE, AMOUNT_DEPOSIT);

            // refund first bidder
            s_amountWithdrawable[firstBidder] = s_bidAmounts[firstBidder];
        }
        else {
            address winningBidder = s_winningBidder;
            // punish the bidder who becomes idle, idle bidder's bid will be taken and divided by this contract:
            uint256 amountTaken = s_bidAmounts[s_opponentBidder[winningBidder]];
            // 80% will be collected by auction factory
            uint256 amountToCollect = amountTaken * FACTORY_COLLECTION_THRESHOLD / PRECISION;
            // 10% to reward the auctioneer
            // 10% to reward the other bidder
            uint256 amountToReward = amountTaken * REWARD_THRESHOLD / PRECISION;
            amountRetrieved = AUCTION_PRICE + amountToCollect;

            // refund winning bidder and give incentive
            s_amountWithdrawable[winningBidder] = s_bidAmounts[winningBidder] + amountToReward;

            // retrieve auction price with amount taken,
            // refund auctioneer and give rewards
            _returnDepositAndFunds(amountRetrieved, AMOUNT_DEPOSIT + amountToReward);
        }
        s_state = State.ENDED;

        emit AuctionCancelled(address(this), auctioneer, amountRetrieved);
    }

    function endAuction()
        external
        onlyAuctioneer
        atState(State.ACTIVE)
    {
        // Auctioneer can end the auction when either of the bid gets $100 or more.
        if (s_currentBid < AUCTION_PRICE) {
            revert HundredDollarAuction__CantEndWhenBidDoesntReachAuctionPrice();
        }
        _endAuction(s_winningBidder);
    }

    // follows CEI
    function withdraw() external atState(State.ENDED) {
        uint256 amountWithdrawable = s_amountWithdrawable[msg.sender];
        if (amountWithdrawable <= 0) {
            revert HundredDollarAuction__NoOutstandingAmountWithdrawable();
        }

        s_amountWithdrawable[msg.sender] = 0;
        _transferUsdt(msg.sender, amountWithdrawable);
    }

    ////////////////////////////
    // Private Functions      //
    ////////////////////////////

    /**
     * @param amountToBid the amount set by first bidder which should be more than or equal to MINIMUM_BID_AMOUNT ($1).
     * 
     * The bidder will occupy the s_firstBidder slot
     */
    function _joinAuctionAsFirstBidder(uint256 amountToBid) private {
        s_firstBidder = msg.sender;
        s_bidAmounts[s_firstBidder] = amountToBid;
        s_numberOfBidders = NumberOfBidders.ONE;
        _collectFromBidder(amountToBid);
        _updateCurrentBid(amountToBid);
    }

    /**
     * @param amountToBid the amount set by second bidder which should be more than the bid of first bidder.
     * 
     * The bidder will occupy the s_secondBidder slot
     */
    function _joinAuctionAsSecondBidder(uint256 amountToBid) private {
        // only two bidders should be able to enter this auction
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
        s_bidAmounts[s_secondBidder] = amountToBid;
        s_state = State.ACTIVE;
        s_numberOfBidders = NumberOfBidders.TWO;

        s_opponentBidder[s_firstBidder] = s_secondBidder;
        s_opponentBidder[s_secondBidder] = s_firstBidder;
        _collectFromBidder(amountToBid);
        _updateCurrentBidAndWinningBidder(amountToBid);
    }

    // when the auction gets cancelled,
    function _returnDepositAndFunds(uint256 amountToFactory, uint256 amountToAuctioneer) private {
        // return the funds to auction factory
        _transferUsdt(i_factory, amountToFactory);
        // return the deposit of auctioneer
        _transferUsdt(s_auctioneer, amountToAuctioneer);
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
        address auctioneer = s_auctioneer;
        // reward the auctioneer based on the auction profit
        int256 auctionProfit = int256(totalBids - AUCTION_PRICE);
        uint256 auctioneerReward;
        if (auctionProfit > 0) {
            auctioneerReward = uint256(auctionProfit) * REWARD_THRESHOLD / PRECISION;
        }
        // amount to return to factory
        uint256 retrieveAmount = totalBids - auctioneerReward;

        s_state = State.ENDED;
        s_amountWithdrawable[winner] = AUCTION_PRICE;
        s_winningBidder = winner;

        _returnDepositAndFunds(retrieveAmount, AMOUNT_DEPOSIT + auctioneerReward);

        emit AuctionEnded(address(this), winner, auctioneer, s_opponentBidder[winner], s_currentBid, s_bidAmounts[s_opponentBidder[winner]], totalBids);
    }

    function _updateCurrentBid(uint256 amountToBid) private {
        s_currentBid = amountToBid;
    }

    function _updateCurrentBidAndWinningBidder(uint256 amountToBid) private {
        _updateCurrentBid(amountToBid);
        s_winningBidder = msg.sender;
    }

    function _updateTimestamp() private {
        s_latestTimestamp = block.timestamp;
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

    function getState() public view returns (State) {
        return s_state;
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

    function getFirstBidder() public view returns (address) {
        return s_firstBidder;
    }

    function getSecondBidder() public view returns (address) {
        return s_secondBidder;
    }

    function getBidAmount(address bidder) public view returns (uint256) {
        return s_bidAmounts[bidder];
    }

    function getCurrentBid() public view returns (uint256) {
        return s_currentBid;
    }

    function getLatestTimestamp() public view returns (uint256) {
        return s_latestTimestamp;
    }

    function getOpponentBidder(address bidder) public view returns (address) {
        return s_opponentBidder[bidder];
    }

    function getWinningBidder() public view returns (address) {
        return s_winningBidder;
    }

    function getAmountWithdrawable(address bidder) public view returns (uint256) {
        return s_amountWithdrawable[bidder];
    }
}
