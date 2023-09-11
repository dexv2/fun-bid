// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployAuctionFactory} from "../../script/DeployAuctionFactory.s.sol";
import {AuctionFactory} from "../../src/AuctionFactory.sol";
import {HundredDollarAuction} from "../../src/HundredDollarAuction.sol";
import {USDTFaucet} from "../../src/USDTFaucet.sol";
import {USDT} from "../../src/USDT.sol";

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
        vm.prank(ALICE);
        faucet.requestUSDT();
        vm.prank(BILLY);
        faucet.requestUSDT();
        vm.prank(CINDY);
        faucet.requestUSDT();
        vm.prank(AUCTIONEER);
        faucet.requestUSDT();

        startingAuctioneerBalance = usdt.balanceOf(AUCTIONEER);
        startingFirstBidderBalance = usdt.balanceOf(ALICE);
        startingSecondBidderBalance = usdt.balanceOf(BILLY);

        // create auction
        vm.startPrank(AUCTIONEER);
        usdt.approve(address(factory), AMOUNT_DEPOSIT);
        auction = factory.openAuction();
        vm.stopPrank();
    }

    modifier firstBidderJoined {
        vm.startPrank(ALICE);
        usdt.approve(address(auction), FIRST_BID_AMOUNT);
        auction.joinAuction(FIRST_BID_AMOUNT);
        vm.stopPrank();
        _;
    }

    modifier secondBidderJoined {
        vm.startPrank(BILLY);
        usdt.approve(address(auction), SECOND_BID_AMOUNT);
        auction.joinAuction(SECOND_BID_AMOUNT);
        vm.stopPrank();
        _;
    }

    function testCanCreateAuctionWithDepositAndFundsForAuctionPrice() public {
        uint256 endingAuctioneerBalance = usdt.balanceOf(AUCTIONEER);

        assertEq(usdt.balanceOf(address(auction)), AUCTION_PRICE + AMOUNT_DEPOSIT);
        assertEq(endingAuctioneerBalance, startingAuctioneerBalance - AMOUNT_DEPOSIT);
    }

    function testAuctioneerCantJoinAuction() public {
        vm.expectRevert(HundredDollarAuction.HundredDollarAuction__AuctioneerCannotJoinAsBidder.selector);
        vm.prank(AUCTIONEER);
        auction.joinAuction(FIRST_BID_AMOUNT);
    }

    function testCannotJoinWithBelowMinimumBidAmount() public {
        uint256 amountToBid = MINIMUM_BID_AMOUNT - 1;
        vm.expectRevert(
            abi.encodeWithSelector(HundredDollarAuction.HundredDollarAuction__BelowMinimumBidAmount.selector, amountToBid)
        );
        vm.prank(ALICE);
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

        vm.startPrank(BILLY);
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
        vm.startPrank(ALICE);
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

        vm.startPrank(ALICE);
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

        vm.startPrank(CINDY);
        usdt.approve(address(auction), amountToIncrementBid);
        vm.expectRevert(
            HundredDollarAuction.HundredDollarAuction__NotABidder.selector
        );
        auction.outbid(amountToIncrementBid);
        vm.stopPrank();
    }

    function testCannotCallOutbidWhenStateIsNotActive()
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

        vm.startPrank(ALICE);
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
         * Current State is OPEN since Second Bidder has not yet joined
         * 
         * enum State {
         *     OPEN         // 0
         *     ACTIVE       // 1
         *     ENDED        // 2
         * }
         * 
         */
        uint256 validStateForOutbidFunction = 0; // OPEN

        vm.startPrank(CINDY);
        usdt.approve(address(auction), SECOND_BID_AMOUNT);

        vm.expectRevert(
            abi.encodeWithSelector(
                HundredDollarAuction.HundredDollarAuction__FunctionCalledAtIncorrectState.selector,
                auction.getState(), // Current State is ACTIVE since Second Bidder has already joined
                validStateForOutbidFunction // Cannot call joinAction when State is not OPEN anymore
            )
        );
        auction.joinAuction(SECOND_BID_AMOUNT);
        vm.stopPrank();
    }

    function testUpdatesBidAmountsAfterOutbidding()
        public
        firstBidderJoined
        secondBidderJoined
    {
        uint256 amountToIncrementBid = 10e18;
        uint256 startingAliceBid = auction.getBidAmount(ALICE);

        vm.startPrank(ALICE);
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

        vm.startPrank(ALICE);
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

        vm.startPrank(ALICE);
        usdt.approve(address(auction), amountToIncrementBid);
        auction.outbid(amountToIncrementBid);
        vm.stopPrank();

        uint256 endingAuctionBalance = usdt.balanceOf(address(auction));

        assertEq(endingAuctionBalance, startingAuctionBalance + amountToIncrementBid);
    }
}
