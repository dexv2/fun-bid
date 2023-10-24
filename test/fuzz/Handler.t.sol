// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Test} from "forge-std/Test.sol";
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

    uint256 MAX_BID_SIZE = type(uint96).max;

    constructor(AuctionFactory _factory, USDT _usdt, HundredDollarAuction _auction, address _auctioneer) {
        factory = _factory;
        usdt = _usdt;
        auction = _auction;
        auctioneer = _auctioneer;
    }

    function joinAuction(uint256 amountToBid) public {
        if (bidders.length == 2) {return;}
        if (bidders[0] == msg.sender) {return;}

        amountToBid = bound(amountToBid, 1, MAX_BID_SIZE);

        vm.prank(address(factory));
        usdt.mint(msg.sender, amountToBid);

        vm.startPrank(msg.sender);
        usdt.approve(address(auction), amountToBid);
        auction.joinAuction(amountToBid);
        vm.stopPrank();

        bidders.push(msg.sender);
    }
}
