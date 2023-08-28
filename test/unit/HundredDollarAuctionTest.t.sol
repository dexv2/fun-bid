// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Test} from "forge-std/Test.sol";
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

    address public ALICE = makeAddr("alice");
    address public BILLY = makeAddr("billy");
    address public CINDY = makeAddr("cindy");
    address public AUCTIONEER = makeAddr("auctioneer");
    uint256 private constant AUCTION_PRICE = 100e18;
    uint256 private constant MINIMUM_BID_AMOUNT = 1e18;
    uint256 private constant AMOUNT_DEPOSIT = 10e18;
    uint256 private startingAuctioneerBalance;

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

        // create auction
        vm.startPrank(AUCTIONEER);
        usdt.approve(address(factory), AMOUNT_DEPOSIT);
        auction = factory.openAuction();
        vm.stopPrank();
    }

    function testCanCreateAuctionWithDepositAndFundsForAuctionPrice() public {
        uint256 endingAuctioneerBalance = usdt.balanceOf(AUCTIONEER);

        assertEq(usdt.balanceOf(address(auction)), AUCTION_PRICE + AMOUNT_DEPOSIT);
        assertEq(endingAuctioneerBalance, startingAuctioneerBalance - AMOUNT_DEPOSIT);
    }

    function testAuctioneerCantJoinAuction() public {
        vm.expectRevert(HundredDollarAuction.HundredDollarAuction__AuctioneerCannotJoinAsBidder.selector);
        vm.prank(AUCTIONEER);
        auction.joinAuction(MINIMUM_BID_AMOUNT);
    }

    function testCannotJoinWithBelowMinimumBidAmount() public {
        uint256 amountToBid = MINIMUM_BID_AMOUNT - 1;
        vm.expectRevert(
            abi.encodeWithSelector(HundredDollarAuction.HundredDollarAuction__BelowMinimumBidAmount.selector, amountToBid)
        );
        vm.prank(AUCTIONEER);
        auction.joinAuction(amountToBid);
    }
}
