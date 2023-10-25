// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {HundredDollarAuction} from "../../src/HundredDollarAuction.sol";
import {AuctionFactory} from "../../src/AuctionFactory.sol";
import {USDT} from "../../src/USDT.sol";

// Auction Contract balance should always be equal to total bids + auction price + deposit amount when the state is not ended
// Auction Contract balance should always be equal to total amount withdrawables when the state is ended
contract Handler is Test {
    error Handler__MintFailed();

    AuctionFactory factory;
    USDT usdt;
    HundredDollarAuction auction;

    address auctioneer;
    address[] bidders;
    bool isFirstBidder = true;

    uint256 private constant MAX_BID_SIZE = type(uint96).max;
    uint256 private constant AUCTION_PRICE = 100e18;
    uint256 private constant MIN_WAITING_TIME = 10800; // 3 hours minimum waiting time before the auction gets cancelled

    constructor(AuctionFactory _factory, USDT _usdt, HundredDollarAuction _auction, address _auctioneer) {
        factory = _factory;
        usdt = _usdt;
        auction = _auction;
        auctioneer = _auctioneer;
    }

    function joinAuction(uint256 amountToBid) public {
        console.log("join auction called");
        console.log("state:", uint256(auction.getState()));
        if (msg.sender == auctioneer) {return;}
        if (uint256(auction.getState()) > 0) {return;}
        if (bidders.length > 0 && bidders[0] == msg.sender) {return;}
        if (auction.getCurrentBid() + 1e18 > MAX_BID_SIZE) {return;}
        amountToBid = bound(amountToBid, auction.getCurrentBid() + 1e18, MAX_BID_SIZE);

        _mintAndApprove(msg.sender, amountToBid);
        vm.prank(msg.sender, msg.sender);
        auction.joinAuction(amountToBid);

        bidders.push(msg.sender);
        console.log("bidders pushed", bidders.length);
    }

    function outbid(uint256 bidIncrement) public {
        console.log("outbid called");
        if (uint256(auction.getState()) != 1) {return;}
        console.log("from outbid");
        console.log("bidders length:", bidders.length);
        address bidder = _getAndToggleBidder();
        uint256 minimumBid = 1e18 + auction.getCurrentBid() - auction.getBidAmount(bidder);
        if (minimumBid > MAX_BID_SIZE) {return;}
        bidIncrement = bound(bidIncrement, minimumBid, MAX_BID_SIZE);

        _mintAndApprove(bidder, bidIncrement);
        vm.prank(bidder);
        auction.outbid(bidIncrement);
    }

    function forfeit() public {
        console.log("forfeit called");
        if (uint256(auction.getState()) != 1) {return;}
        console.log("from forfeit");
        console.log("bidders length:", bidders.length);
        address bidder = _getAndToggleBidder();

        vm.prank(bidder);
        auction.forfeit();
    }

    function cancelAuction() public {
        console.log("cancel called");
        if (uint256(auction.getState()) == 2) {return;}

        uint256 timeSnapshot = auction.getLatestTimestamp();
        uint256 timeElapsed = timeSnapshot + MIN_WAITING_TIME + 10;
        vm.warp(timeElapsed);

        vm.prank(auctioneer);
        auction.cancelAuction();
    }

    function endAuction() public {
        console.log("end auction called");
        if (uint256(auction.getState()) != 1) {return;}
        if (auction.getCurrentBid() < AUCTION_PRICE) {return;}
        console.log("end auction passed");

        vm.prank(auctioneer);
        auction.endAuction();
    }

    function withdraw() public {
        console.log("withdraw called");
        if (bidders.length == 0) {return;}
        if (uint256(auction.getState()) != 2) {return;}
        console.log("withdraw state:", uint256(auction.getState()));
        console.log("withdraw bidders length:", bidders.length);
        address bidder;
        if (bidders.length == 1) {
            bidder = bidders[0];
        }
        else {
            bidder = _getAndToggleBidder();
        }

        if (auction.getAmountWithdrawable(bidder) <= 0) {return;}

        vm.prank(bidder);
        auction.withdraw();
    }

    function _mintAndApprove(address bidder, uint256 amount) private {
        vm.prank(address(factory));
        usdt.mint(bidder, amount);

        vm.prank(bidder);
        usdt.approve(address(auction), amount);
    }

    function _getAndToggleBidder() private returns (address) {
        console.log("bidders length from toggle:", bidders.length);
        bool _isFirstBidder = isFirstBidder;
        isFirstBidder = !_isFirstBidder;
        if (_isFirstBidder) {
            return bidders[0];
        }
        return bidders[1];
    }

    function _getBidderFromSeed(uint256 seed) private view returns (address) {
        return bidders[seed % 2];
    }
}
