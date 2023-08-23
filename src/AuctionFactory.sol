// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import {USDTest} from "./USDTest.sol";
import {HundredDollarAuction} from "./HundredDollarAuction.sol";
import {USDTestFaucet} from "./USDTestFaucet.sol";

/**
 * @title AuctionFactory
 * @author Vermont Phil Paguiligan
 * @notice This contract is the owner of USDTest token and the funder of all the auctions created.
 * 
 * Role of this contract:
 * 
 * 1. Create an Auction contract which is initiated by a user who wants to oversee an auction.
 * 2. Fund the Auction contract by 100 USDTest upon creation which should be the price of the winning bidder.
 */
contract AuctionFactory is Ownable {
    error AuctionFactory__TransferFailed();
    error AuctionFactory__MintFailed();

    uint256 private constant AUCTION_PRICE = 100e18;
    uint256 private constant AUCTIONEERDEPOSIT = 10e18;

    address[] private auctionList;
    address private immutable i_faucet;
    USDTest private immutable i_usdt;

    event HundredDollarAuctionCreated(address indexed Auction);

    constructor(USDTest usdt, address faucet) {
        i_usdt = usdt;
        i_faucet = faucet;
    }

    /**
     * The user who calls this function will become an auctioneer who will oversee this auction.
     * Upon starting the auction, the user deposits 10 USDTest which will be returned after the auction has ended.
     */
    function openAuction() public {
        HundredDollarAuction auction = new HundredDollarAuction(i_usdt, msg.sender);
        auctionList.push(address(auction));

        bool success = i_usdt.transferFrom(msg.sender, address(auction), AUCTIONEERDEPOSIT);
        if (!success) {
            revert AuctionFactory__TransferFailed();
        }

        /**
         * The Auction contract gets a fund for the winning bidder.
         */
        bool minted = i_usdt.mint(address(auction), AUCTION_PRICE);
        if (!minted) {
            revert AuctionFactory__MintFailed();
        }

        emit HundredDollarAuctionCreated(address(auction));
    }

    function fundFaucet(uint256 amountToFund) public onlyOwner {
        bool minted = i_usdt.mint(i_faucet, amountToFund);
        if (!minted) {
            revert AuctionFactory__MintFailed();
        }
    }
}
