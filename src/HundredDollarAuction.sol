// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import {USDTest} from "./USDTest.sol";

/**
 * @title HundredDollarAuction
 * @author Vermont Phil Paguiligan
 * 
 * @notice BUY MY $100 FOR ONLY $1.
 * 
 * This contract holds 100 USDTest which can be bought for at least 1 USDTest.
 * 
 * But here's the catch:
 * 
 * 1. There should be 2 bidders to compete.
 * 2. The other bidder should forfeit for you to win.
 * 3. When the game ends, the winning and losing bid will be collected by this contract.
 *    And the price of $100 USDTest will be given to the highest bidder.
 * 4. When either of the bid reaches 100 USDTest, the owner of the contract can end the
 *    game anytime.
 */
contract HundredDollarAuction is Ownable {
    error HundredDollarAuction__AuctionOccupied();
    error HundredDollarAuction__AmountDidNotOutbid();
    error HundredDollarAuction__NotABidder();

    uint256 private constant INITIAL_BID_AMOUNT = 1e18;

    mapping (address bidder => uint256 bidAmount) s_bidAmounts;
    address private s_firstBidder;
    address private s_secondBidder;
    USDTest private immutable i_usdt;

    constructor(USDTest usdt, address firstBidder) {
        i_usdt = usdt;
        s_firstBidder = firstBidder;
        s_bidAmounts[s_firstBidder] = INITIAL_BID_AMOUNT;
    }

    modifier onlyBidder {
        if (msg.sender != s_firstBidder || msg.sender != s_secondBidder) {
            revert HundredDollarAuction__NotABidder();
        }
        _;
    }

    function joinBid(uint256 bidAmount) public {
        if (s_secondBidder != address(0)) {
            revert HundredDollarAuction__AuctionOccupied();
        }
        if (bidAmount <= INITIAL_BID_AMOUNT) {
            revert HundredDollarAuction__AmountDidNotOutbid();
        }

        s_secondBidder = msg.sender;
        s_bidAmounts[s_secondBidder] = INITIAL_BID_AMOUNT;
    }

    function outBid(uint256 bidIncrement) public onlyBidder {}

    function forfeit() public onlyBidder {}

    function collect() public onlyOwner {}
}
