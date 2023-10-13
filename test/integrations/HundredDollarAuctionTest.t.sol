// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployAuctionFactory} from "../../script/DeployAuctionFactory.s.sol";
import {FactoryOpenAuction} from "../../script/Interactions/AuctionFactory.s.sol";
import {JoinAuction, OutbidAuction, ForfeitAuction, CancelAuction, EndAuction, WithdrawAuction} from "../../script/Interactions/HundredDollarAuction.s.sol";
import {FaucetRequestUSDT} from "../../script/Interactions/USDTFaucet.s.sol";
import {HundredDollarAuction} from "../../src/HundredDollarAuction.sol";
import {AuctionFactory} from "../../src/AuctionFactory.sol";
import {USDTFaucet} from "../../src/USDTFaucet.sol";
import {USDT} from "../../src/USDT.sol";

contract HundredDollarAuctionTestIntegrations is Test {
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
    uint256 private constant MIN_WAITING_TIME = 10800; // 3 hours minimum waiting time before the auction gets cancelled

    function setUp() public {
        DeployAuctionFactory deployer = new DeployAuctionFactory();
        (factory, usdt, faucet) = deployer.run();
        console.log("factory address:", address(factory));
        console.log("usdt address:", address(usdt));
        console.log("faucet address:", address(faucet));

        FaucetRequestUSDT requestUsdt = new FaucetRequestUSDT();
        FactoryOpenAuction openAuction = new FactoryOpenAuction();

        // fund users to test
        requestUsdt.execute(address(faucet), ALICE);
        requestUsdt.execute(address(faucet), BILLY);
        requestUsdt.execute(address(faucet), CINDY);
        requestUsdt.execute(address(faucet), AUCTIONEER);

        // create auction
        auction = HundredDollarAuction(
            openAuction.execute(
                address(factory),
                address(faucet),
                address(usdt),
                AUCTIONEER
            )
        );
    }

    function _joinAuction(address account, uint256 amountToBid) private {
        JoinAuction joinAuction = new JoinAuction();
        joinAuction.execute(address(auction), amountToBid, address(usdt), account);
    }

    function _outbidAuction(address account, uint256 bidIncrement) private {
        OutbidAuction outbidAuction = new OutbidAuction();
        outbidAuction.execute(address(auction), bidIncrement, address(usdt), account);
    }

    function _forfeitAuction(address account) private {
        ForfeitAuction forfeitAuction = new ForfeitAuction();
        forfeitAuction.execute(address(auction), account);
    }

    function _cancelAuction(address account) private {
        CancelAuction cancelAuction = new CancelAuction();
        cancelAuction.execute(address(auction), account);
    }

    function _endAuction(address account) private {
        EndAuction endAuction = new EndAuction();
        endAuction.execute(address(auction), account);
    }

    function _withdrawAuction(address account) private {
        WithdrawAuction withdrawAuction = new WithdrawAuction();
        withdrawAuction.execute(address(auction), account);
    }

    function _joinAuctionAndOutbidEachOther() private {
        uint256 amountToIncrementBidAlice = 90e18;
        uint256 amountToIncrementBidBilly = 95e18;
        _joinAuction(ALICE, FIRST_BID_AMOUNT);
        _joinAuction(BILLY, SECOND_BID_AMOUNT);
        _outbidAuction(ALICE, amountToIncrementBidAlice);
        _outbidAuction(BILLY, amountToIncrementBidBilly);
    }

    function testUsersCanJoinAuctionAndOutBidInteractions() public {
        uint256 startingBalanceAlice = usdt.balanceOf(ALICE);
        uint256 startingBalanceBilly = usdt.balanceOf(BILLY);

        _joinAuctionAndOutbidEachOther();

        uint256 endingBalanceAlice = usdt.balanceOf(ALICE);
        uint256 endingBalanceBilly = usdt.balanceOf(BILLY);

        assertEq(startingBalanceAlice, endingBalanceAlice + auction.getBidAmount(ALICE));
        assertEq(startingBalanceBilly, endingBalanceBilly + auction.getBidAmount(BILLY));
    }

    function testBidderCanForfeitAndWinnerCanWithdrawPriceInteractions() public {
        _joinAuctionAndOutbidEachOther();
        _forfeitAuction(ALICE);

        uint256 balanceBeforeWithdrawalBilly = usdt.balanceOf(BILLY);
        uint256 amountWithdrawable = auction.getAmountWithdrawable(BILLY);
        _withdrawAuction(BILLY);
        uint256 balanceAfterWithdrawalBilly = usdt.balanceOf(BILLY);

        assertEq(auction.getWinningBidder(), BILLY);
        assertEq(amountWithdrawable, AUCTION_PRICE);
        assertEq(balanceAfterWithdrawalBilly, balanceBeforeWithdrawalBilly + AUCTION_PRICE);
    }

    function testAuctioneerCanEndAuctionAndWinnerCanWithdrawInteractions() public {
        // Billy is the last to bid so he is the winner
        _joinAuctionAndOutbidEachOther();
        _endAuction(AUCTIONEER);

        uint256 balanceBeforeWithdrawalBilly = usdt.balanceOf(BILLY);
        uint256 amountWithdrawable = auction.getAmountWithdrawable(BILLY);
        _withdrawAuction(BILLY);
        uint256 balanceAfterWithdrawalBilly = usdt.balanceOf(BILLY);

        assertEq(auction.getWinningBidder(), BILLY);
        assertEq(amountWithdrawable, AUCTION_PRICE);
        assertEq(balanceAfterWithdrawalBilly, balanceBeforeWithdrawalBilly + AUCTION_PRICE);
    }

    function testAuctioneerCanCancelAuctionInteractions() public {
        // more than 3 hours waiting time
        vm.warp(block.timestamp + MIN_WAITING_TIME + 10);

        uint256 startingBalanceFactory = usdt.balanceOf(address(factory));
        uint256 startingBalanceAuctioneer = usdt.balanceOf(AUCTIONEER);
        _cancelAuction(AUCTIONEER);

        uint256 endingBalanceFactory = usdt.balanceOf(address(factory));
        uint256 endingBalanceAuctioneer = usdt.balanceOf(AUCTIONEER);

        assertEq(endingBalanceFactory, startingBalanceFactory + AUCTION_PRICE);
        assertEq(endingBalanceAuctioneer, startingBalanceAuctioneer + AMOUNT_DEPOSIT);
    }
}
