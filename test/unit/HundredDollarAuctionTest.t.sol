// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployAuctionFactory} from "../../script/DeployAuctionFactory.s.sol";
import {AuctionFactory} from "../../src/AuctionFactory.sol";
import {HundredDollarAuction} from "../../src/HundredDollarAuction.sol";
import {USDTFaucet} from "../../src/USDTFaucet.sol";
import {USDT} from "../../src/USDT.sol";
import {MockBidderContract} from "../mocks/MockBidderContract.sol";
import {MockAuctioneerContract} from "../mocks/MockAuctioneerContract.sol";

// Auction Contract balance should be 0 after the auction ends
contract HundredDollarAuctionTest is Test {
    AuctionFactory factory;
    USDTFaucet faucet;
    USDT usdt;
    HundredDollarAuction auction;

    // We will set ALICE as first bidder
    address public ALICE = makeAddr("alice");
    // We will set BILLY as second bidder
    address public BILLY = makeAddr("billy");
    address public CINDY = makeAddr("cindy");
    address public AUCTIONEER = makeAddr("auctioneer");
    uint256 private constant AUCTION_PRICE = 100e18;
    uint256 private constant FIRST_BID_AMOUNT = 1e18;
    uint256 private constant SECOND_BID_AMOUNT = 5e18;
    uint256 private constant MINIMUM_BID_AMOUNT = 1e18;
    uint256 private constant AMOUNT_DEPOSIT = 10e18;
    uint256 private startingAuctioneerBalance;
    uint256 private startingFirstBidderBalance;
    uint256 private startingSecondBidderBalance;

    function setUp() public {
        DeployAuctionFactory deployer = new DeployAuctionFactory();
        (factory, usdt, faucet) = deployer.run();

        // fund users to test
        vm.prank(ALICE, ALICE);
        faucet.requestUSDT();
        vm.prank(BILLY, BILLY);
        faucet.requestUSDT();
        vm.prank(CINDY, CINDY);
        faucet.requestUSDT();
        vm.prank(AUCTIONEER, AUCTIONEER);
        faucet.requestUSDT();

        startingAuctioneerBalance = usdt.balanceOf(AUCTIONEER);
        startingFirstBidderBalance = usdt.balanceOf(ALICE);
        startingSecondBidderBalance = usdt.balanceOf(BILLY);

        // // create auction
        vm.startPrank(AUCTIONEER, AUCTIONEER);
        usdt.approve(address(factory), AMOUNT_DEPOSIT);
        auction = HundredDollarAuction(factory.openAuction());
        vm.stopPrank();
    }

    modifier firstBidderJoined {
        _joinAsFirstBidder();
        _;
    }

    modifier secondBidderJoined {
        _joinAsSecondBidder();
        _;
    }

    function _joinAsFirstBidder() private {
        vm.startPrank(ALICE, ALICE);
        usdt.approve(address(auction), FIRST_BID_AMOUNT);
        auction.joinAuction(FIRST_BID_AMOUNT);
        vm.stopPrank();
    }

    function _joinAsSecondBidder() private {
        vm.startPrank(BILLY, BILLY);
        usdt.approve(address(auction), SECOND_BID_AMOUNT);
        auction.joinAuction(SECOND_BID_AMOUNT);
        vm.stopPrank();
    }

    // function testUpdatesTimestampWhenJoiningTheBid() public {
    //     uint256 timestamp1 = auction.getLatestTimestamp();
    //     _joinAsFirstBidder();
    //     uint256 timestamp2 = auction.getLatestTimestamp();
    //     _joinAsSecondBidder();
    //     uint256 timestamp3 = auction.getLatestTimestamp();

    //     console.log(timestamp1, timestamp2, timestamp3, block.timestamp);

    //     assert(timestamp2 > timestamp1);
    //     assert(timestamp3 > timestamp2);
    // }

    function testCannotJoinBidIfNotEOA() public {
        vm.startPrank(ALICE, ALICE);
        MockBidderContract mockBidderContract = new MockBidderContract();
        usdt.approve(address(mockBidderContract), FIRST_BID_AMOUNT);
        vm.expectRevert(
            HundredDollarAuction.HundredDollarAuction__NotEOA.selector
        );
        mockBidderContract.joinAuction(address(auction), address(usdt), FIRST_BID_AMOUNT);
        vm.stopPrank();
    }

    function testCannotBeAnAuctioneerIfNotEOA() public {
        vm.startPrank(AUCTIONEER, AUCTIONEER);
        MockAuctioneerContract mockAuctioneerContract = new MockAuctioneerContract();
        usdt.approve(address(mockAuctioneerContract), AMOUNT_DEPOSIT);
        vm.expectRevert(
            AuctionFactory.AuctionFactory__NotEOA.selector
        );
        mockAuctioneerContract.openAuction(address(factory), address(usdt));
        vm.stopPrank();
    }

    function testCanCreateAuctionWithDepositAndFundsForAuctionPrice() public {
        uint256 endingAuctioneerBalance = usdt.balanceOf(AUCTIONEER);

        assertEq(usdt.balanceOf(address(auction)), AUCTION_PRICE + AMOUNT_DEPOSIT);
        assertEq(endingAuctioneerBalance, startingAuctioneerBalance - AMOUNT_DEPOSIT);
    }

    function testAuctioneerCannotJoinAuction() public {
        vm.expectRevert(HundredDollarAuction.HundredDollarAuction__AuctioneerCannotJoinAsBidder.selector);
        vm.prank(AUCTIONEER, AUCTIONEER);
        auction.joinAuction(FIRST_BID_AMOUNT);
    }

    function testCannotJoinWithBelowMinimumBidAmount() public {
        uint256 amountToBid = MINIMUM_BID_AMOUNT - 1;
        vm.expectRevert(
            abi.encodeWithSelector(HundredDollarAuction.HundredDollarAuction__BelowMinimumBidAmount.selector, amountToBid)
        );
        vm.prank(ALICE, ALICE);
        auction.joinAuction(amountToBid);
    }

    function testShouldCollectBidFromFirstBidderWhenFirstBidderJoins() public firstBidderJoined {
        uint256 endingFirstBidderBalance = usdt.balanceOf(ALICE);
        uint256 expectedAuctionBalance = AUCTION_PRICE + AMOUNT_DEPOSIT + FIRST_BID_AMOUNT;
        assertEq(usdt.balanceOf(address(auction)), expectedAuctionBalance);
        assertEq(endingFirstBidderBalance, startingFirstBidderBalance - FIRST_BID_AMOUNT);
    }

    function testShouldUpdateFirstBidderAddressWhenFirstBidderJoins() public firstBidderJoined {
        assertEq(auction.getFirstBidder(), ALICE);
    }

    function testShouldUpdateAmountBidOfFirstBidderWhenFirstBidderJoins() public firstBidderJoined {
        assertEq(auction.getBidAmount(ALICE), FIRST_BID_AMOUNT);
    }

    function testNumberOfBiddersShouldBeOneAfterFirstBidderJoined() public firstBidderJoined {
        uint8 expectedNumberOfBidders = 1;

        assertEq(uint8(auction.getNumberOfBidders()), expectedNumberOfBidders);
    }

    function testShouldUpdateCurrentBidWithFirstBiddersBidAfterFirstBidderJoined() public firstBidderJoined {
        assertEq(auction.getCurrentBid(), FIRST_BID_AMOUNT);
    }

    function testCannotJoinWhenTheAmountWillNotOutbidTheFirstBidder() public firstBidderJoined {
        // same amount as first bidder, means it will not outbid
        uint256 amountToBid = FIRST_BID_AMOUNT;

        vm.startPrank(BILLY, BILLY);
        usdt.approve(address(auction), amountToBid);

        vm.expectRevert(
            abi.encodeWithSelector(
                HundredDollarAuction.HundredDollarAuction__AmountDidNotOutbid.selector,
                auction.getCurrentBid(),
                amountToBid
            )
        );
        auction.joinAuction(amountToBid);
        vm.stopPrank();
    }

    function testFirstBidderCannotJoinAsSecondBidder() public firstBidderJoined {
        // Alice is the first bidder
        vm.startPrank(ALICE, ALICE);
        usdt.approve(address(auction), SECOND_BID_AMOUNT);

        vm.expectRevert(
            HundredDollarAuction.HundredDollarAuction__TheSameBidderNotAllowed.selector
        );
        auction.joinAuction(SECOND_BID_AMOUNT);
        vm.stopPrank();
    }

    function testShouldCollectBidFromSecondBidderWhenSecondBidderJoins()
        public
        firstBidderJoined
        secondBidderJoined
    {
        uint256 endingSecondBidderBalance = usdt.balanceOf(BILLY);
        uint256 expectedAuctionBalance = AUCTION_PRICE + AMOUNT_DEPOSIT + FIRST_BID_AMOUNT + SECOND_BID_AMOUNT;
        assertEq(usdt.balanceOf(address(auction)), expectedAuctionBalance);
        assertEq(endingSecondBidderBalance, startingSecondBidderBalance - SECOND_BID_AMOUNT);
    }

    function testShouldUpdateSecondBidderAddressWhenSecondBidderJoins()
        public
        firstBidderJoined
        secondBidderJoined
    {
        assertEq(auction.getSecondBidder(), BILLY);
    }

    function testShouldUpdateAmountBidOfSecondBidderWhenSecondBidderJoins()
        public
        firstBidderJoined
        secondBidderJoined
    {
        assertEq(auction.getBidAmount(BILLY), SECOND_BID_AMOUNT);
    }

    function testNumberOfBiddersShouldBeTwoAfterSecondBidderJoined()
        public
        firstBidderJoined
        secondBidderJoined
    {
        uint8 expectedNumberOfBidders = 2;
        assertEq(uint8(auction.getNumberOfBidders()), expectedNumberOfBidders);
    }

    function testShouldUpdateStateToActiveAfterSecondBidderJoined()
        public
        firstBidderJoined
        secondBidderJoined
    {
        /**
         * 
         * enum State {
         *     OPEN         // 0
         *     ACTIVE       // 1
         *     ENDED        // 2
         * }
         * 
         */
        uint8 expectedState = 1;

        assertEq(uint8(auction.getState()), expectedState);
    }

    function testShouldUpdateCurrentBidWithSecondBiddersBidAfterSecondBidderJoined()
        public
        firstBidderJoined
        secondBidderJoined
    {
        assertEq(auction.getCurrentBid(), SECOND_BID_AMOUNT);
    }

    function testShouldUpdateWinningBidderToSecondBidderWhenSecondBidderJoins()
        public
        firstBidderJoined
        secondBidderJoined
    {
        assertEq(auction.getWinningBidder(), BILLY);
    }

    function testShouldHaveNoWinningBidderYetIfNoSecondBidder()
        public
        firstBidderJoined
    {
        assertEq(auction.getWinningBidder(), address(0));
    }

    function testSetOpponentBiddersAsEachOtherAfterSecondBidderJoined()
        public
        firstBidderJoined
        secondBidderJoined
    {
        assertEq(auction.getOpponentBidder(ALICE), BILLY);
        assertEq(auction.getOpponentBidder(BILLY), ALICE);
    }

    function testShouldHaveNoOpponentWhenNotABidder()
        public
        firstBidderJoined
        secondBidderJoined
    {
        assertEq(auction.getOpponentBidder(CINDY), address(0));
    }

    function testShouldHaveNoOpponentYetWhileWhenTheFirstBidderJoins()
        public
        firstBidderJoined
    {
        assertEq(auction.getOpponentBidder(ALICE), address(0));
    }

    function testRevertsIfBidderTriesToOutbidWithLessThanCurrentBid()
        public
        firstBidderJoined
        secondBidderJoined
    {
        // Current bid amounts per bidder:
        // First bidder (ALICE): $1
        // Second bidder (BILLY): $5

        uint256 amountToIncrementBid = 3e18;
        uint256 currentBid = auction.getCurrentBid();
        uint256 aliceBidAmount = auction.getBidAmount(ALICE);
        uint256 amountToOutbid = aliceBidAmount + amountToIncrementBid;

        vm.startPrank(ALICE, ALICE);
        usdt.approve(address(auction), amountToIncrementBid);

        vm.expectRevert(
            abi.encodeWithSelector(
                HundredDollarAuction.HundredDollarAuction__AmountDidNotOutbid.selector,
                currentBid,
                amountToOutbid
            )
        );

        // ALICE's bid after calling function outbid: $4
        // $4 < $5 means it will not outbid BILLY and will revert
        auction.outbid(amountToIncrementBid);
        vm.stopPrank();
    }

    function testCannotOutbidIfNotABidder()
        public
        firstBidderJoined
        secondBidderJoined
    {
        uint256 amountToIncrementBid = 3e18;

        vm.startPrank(CINDY, CINDY);
        usdt.approve(address(auction), amountToIncrementBid);
        vm.expectRevert(
            HundredDollarAuction.HundredDollarAuction__NotABidder.selector
        );
        auction.outbid(amountToIncrementBid);
        vm.stopPrank();
    }

    function testCannotOutbidWhenStateIsNotActive()
        public
        firstBidderJoined
    {
        /**
         * 
         * Current State is OPEN since Second Bidder has not yet joined
         * 
         * enum State {
         *     OPEN         // 0
         *     ACTIVE       // 1
         *     ENDED        // 2
         * }
         * 
         */
        uint256 validStateForOutbidFunction = 1; // ACTIVE
        uint256 amountToIncrementBid = 3e18;

        vm.startPrank(ALICE, ALICE);
        usdt.approve(address(auction), amountToIncrementBid);
        vm.expectRevert(
            abi.encodeWithSelector(
                HundredDollarAuction.HundredDollarAuction__FunctionCalledAtIncorrectState.selector,
                auction.getState(), // Current State is OPEN since Second Bidder has not yet joined
                validStateForOutbidFunction // State should be ACTIVE to call outbid function
            )
        );
        auction.outbid(amountToIncrementBid);
        vm.stopPrank();
    }

    function testCannotCallJoinBidWhenTheStateIsAlreadyActive()
        public
        firstBidderJoined
        secondBidderJoined
    {
        /**
         * 
         * Current State is ACTIVE since Second Bidder has already joined
         * 
         * enum State {
         *     OPEN         // 0
         *     ACTIVE       // 1
         *     ENDED        // 2
         * }
         * 
         */
        uint256 validStateForJoinAuctionFunction = 0; // OPEN

        vm.startPrank(CINDY, CINDY);
        usdt.approve(address(auction), SECOND_BID_AMOUNT);

        vm.expectRevert(
            abi.encodeWithSelector(
                HundredDollarAuction.HundredDollarAuction__FunctionCalledAtIncorrectState.selector,
                auction.getState(), // Current State is ACTIVE since Second Bidder has already joined
                validStateForJoinAuctionFunction // Cannot call joinAction when State is not OPEN anymore
            )
        );
        auction.joinAuction(SECOND_BID_AMOUNT);
        vm.stopPrank();
    }

    function testSetStateAsActiveWhenTwoBiddersJoined()
        public
        firstBidderJoined
        secondBidderJoined
    {
        /**
         * 
         * enum State {
         *     OPEN         // 0
         *     ACTIVE       // 1
         *     ENDED        // 2
         * }
         * 
         */

        uint256 activeState = 1;
        
        assertEq(uint256(auction.getState()), activeState);
    }

    function testUpdatesBidAmountsAfterOutbidding()
        public
        firstBidderJoined
        secondBidderJoined
    {
        uint256 amountToIncrementBid = 10e18;
        uint256 startingAliceBid = auction.getBidAmount(ALICE);

        vm.startPrank(ALICE, ALICE);
        usdt.approve(address(auction), amountToIncrementBid);
        auction.outbid(amountToIncrementBid);
        vm.stopPrank();

        uint256 currentBid = auction.getCurrentBid();
        uint256 endingAliceBid = auction.getBidAmount(ALICE);

        assertEq(currentBid, endingAliceBid);
        assertEq(endingAliceBid, startingAliceBid + amountToIncrementBid);
    }

    function testUpdatesWinningBidderAfterOutbidding()
        public
        firstBidderJoined
        secondBidderJoined
    {
        uint256 amountToIncrementBid = 10e18;

        vm.startPrank(ALICE, ALICE);
        usdt.approve(address(auction), amountToIncrementBid);
        auction.outbid(amountToIncrementBid);
        vm.stopPrank();

        assertEq(auction.getWinningBidder(), ALICE);
    }

    function testCollectUsdtFromBidderAfterOutbidding()
        public
        firstBidderJoined
        secondBidderJoined
    {
        uint256 amountToIncrementBid = 10e18;
        uint256 startingAuctionBalance = usdt.balanceOf(address(auction));

        vm.startPrank(ALICE, ALICE);
        usdt.approve(address(auction), amountToIncrementBid);
        auction.outbid(amountToIncrementBid);
        vm.stopPrank();

        uint256 endingAuctionBalance = usdt.balanceOf(address(auction));

        assertEq(endingAuctionBalance, startingAuctionBalance + amountToIncrementBid);
    }

    function testCannotForfeitWhenTheStateIsNotActive()
        public
        firstBidderJoined
    {
        /**
         * 
         * Current State is OPEN since Second Bidder has not yet joined
         * 
         * enum State {
         *     OPEN         // 0
         *     ACTIVE       // 1
         *     ENDED        // 2
         * }
         * 
         */
        uint256 validStateForForfeitFunction = 1; // ACTIVE

        vm.expectRevert(
            abi.encodeWithSelector(
                HundredDollarAuction.HundredDollarAuction__FunctionCalledAtIncorrectState.selector,
                auction.getState(), // Current State is OPEN since Second Bidder has not yet joined
                validStateForForfeitFunction // State should be ACTIVE to call forfeit function
            )
        );
        vm.prank(ALICE, ALICE);
        auction.forfeit();
    }

    function testCannotForfeitIfNotABidder()
        public
        firstBidderJoined
        secondBidderJoined
    {
        vm.expectRevert(
            HundredDollarAuction.HundredDollarAuction__NotABidder.selector
        );
        vm.prank(CINDY, CINDY);
        auction.forfeit();
    }

    function testSetStateAsEndedWhenABidderForfeits()
        public
        firstBidderJoined
        secondBidderJoined
    {
        /**
         * 
         * enum State {
         *     OPEN         // 0
         *     ACTIVE       // 1
         *     ENDED        // 2
         * }
         * 
         */

        uint256 endedState = 2;

        vm.prank(ALICE, ALICE);
        auction.forfeit();

        assertEq(uint256(auction.getState()), endedState);
    }

    function testSetOpponentAsWinnerWhenBidderForfeits()
        public
        firstBidderJoined
        secondBidderJoined
    {
        vm.prank(ALICE, ALICE);
        auction.forfeit();

        address winner = auction.getWinningBidder();
        address opponent = auction.getOpponentBidder(ALICE);

        assertEq(winner, opponent);
    }

    function testWinnerCanWithdrawAuctionPriceWhenOpponentForfeits()
        public
        firstBidderJoined
        secondBidderJoined
    {
        vm.prank(ALICE, ALICE);
        auction.forfeit();

        address winner = auction.getWinningBidder();
        uint256 amountWithdrawable = auction.getAmountWithdrawable(winner);
        uint256 startingWinnerBalance = usdt.balanceOf(winner);

        vm.prank(winner);
        auction.withdraw();

        uint256 endingWinnerBalance = usdt.balanceOf(winner);

        assertEq(amountWithdrawable, AUCTION_PRICE);
        assertEq(endingWinnerBalance, startingWinnerBalance + amountWithdrawable);
    }

    function testAuctioneerWillReceiveTheDepositedAmountWhenBidderForfeits()
        public
        firstBidderJoined
        secondBidderJoined
    {
        uint256 auctioneerBalanceBeforeForfeit = usdt.balanceOf(AUCTIONEER);

        vm.prank(ALICE, ALICE);
        auction.forfeit();

        uint256 auctioneerBalanceAfterForfeit = usdt.balanceOf(AUCTIONEER);

        assertEq(auctioneerBalanceAfterForfeit, auctioneerBalanceBeforeForfeit + AMOUNT_DEPOSIT);
    }

    function testFactoryWillReceiveTheTotalBidsWhenBidderForfeits()
        public
        firstBidderJoined
        secondBidderJoined
    {
        uint256 totalBids = auction.getTotalBids();
        uint256 factoryBalanceBeforeForfeit = usdt.balanceOf(address(factory));

        vm.prank(ALICE, ALICE);
        auction.forfeit();

        uint256 factoryBalanceAfterForfeit = usdt.balanceOf(address(factory));

        assertEq(factoryBalanceAfterForfeit, factoryBalanceBeforeForfeit + totalBids);
    }
}
