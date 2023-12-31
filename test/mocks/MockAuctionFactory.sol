// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {USDT} from "../../src/USDT.sol";
import {HundredDollarAuction} from "../../src/HundredDollarAuction.sol";
import {USDTFaucet} from "../../src/USDTFaucet.sol";

/**
 * @title AuctionFactory
 * @author Vermont Phil Paguiligan
 * @notice This contract is the owner of USDT token and the funder of all the auctions created.
 * 
 * Role of this contract:
 * 
 * 1. Create an Auction contract which is initiated by a user who wants to oversee an auction.
 * 2. Fund the Auction contract by 100 USDT upon creation which should be the price of the winning bidder.
 */
contract MockAuctionFactory is Ownable {
    error AuctionFactory__NotEOA();

    uint256 private constant AUCTION_PRICE = 100e18;
    uint256 private constant AMOUNT_DEPOSIT = 10e18;

    address[] private auctionList;
    address private immutable i_faucet;
    USDT private immutable i_usdt;

    event HundredDollarAuctionCreated(address indexed Auction);

    constructor(address usdt, address faucet) {
        i_usdt = USDT(usdt);
        i_faucet = faucet;
    }

    /**
     * The user who calls this function will become an auctioneer who will oversee this auction.
     * Upon starting the auction, the user deposits 10 USDT which will be returned after the auction has ended.
     */
    function openAuction() public returns (address) {
        if (msg.sender != tx.origin) {
            revert AuctionFactory__NotEOA();
        }

        HundredDollarAuction auction = new HundredDollarAuction(i_usdt, msg.sender);
        auctionList.push(address(auction));

        i_usdt.transferFrom(msg.sender, address(auction), AMOUNT_DEPOSIT);

        /**
         * The Auction contract gets a fund for the winning bidder.
         */
        i_usdt.mint(address(auction), AUCTION_PRICE);

        emit HundredDollarAuctionCreated(address(auction));

        return address(auction);
    }
}
