// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Test} from "forge-std/Test.sol";
import {HundredDollarAuction} from "../../src/HundredDollarAuction.sol";
import {AuctionFactory} from "../../src/AuctionFactory.sol";
import {USDT} from "../../src/USDT.sol";

// Auction Contract balance should always be equal to total bids + auction price + deposit amount when the state is not ended
// Auction Contract balance should always be equal to total amount withdrawables when the state is ended
contract Handler is Test {
    AuctionFactory factory;
    USDT usdt;
    HundredDollarAuction auction;

    constructor(AuctionFactory _factory, USDT _usdt, HundredDollarAuction _auction) {
        factory = _factory;
        usdt = _usdt;
        auction = _auction;
    }
}
