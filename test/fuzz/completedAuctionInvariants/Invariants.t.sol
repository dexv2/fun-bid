// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployAuctionFactory} from "../../../script/DeployAuctionFactory.s.sol";
import {HundredDollarAuction} from "../../../src/HundredDollarAuction.sol";
import {AuctionFactory} from "../../../src/AuctionFactory.sol";
import {USDT} from "../../../src/USDT.sol";
import {Handler} from "./Handler.t.sol";

/**
 * Invariants:
 * 
 * State is active:
 * Auction Contract balance should always be equal to total bids + auction price + deposit amount
 * 
 * State is ended:
 * Auction Contract balance should always be equal to total amount withdrawables with negligible discrepancy
 * 
 */
contract InvariantsTestCompletedAuction is StdInvariant, Test {
    DeployAuctionFactory deployer;
    AuctionFactory factory;
    HundredDollarAuction auction;
    USDT usdt;
    Handler handler;
    address public AUCTIONEER = makeAddr("auctioneer");
    uint256 private constant AMOUNT_DEPOSIT = 10e18;
    uint256 private constant AUCTION_PRICE = 100e18;

    function setUp() public {
        deployer = new DeployAuctionFactory();
        (factory, usdt, ) = deployer.run();

        vm.prank(address(factory));
        usdt.mint(AUCTIONEER, AMOUNT_DEPOSIT);

        vm.startPrank(AUCTIONEER, AUCTIONEER);
        usdt.approve(address(factory), AMOUNT_DEPOSIT);
        auction = HundredDollarAuction(factory.openAuction());
        vm.stopPrank();

        handler = new Handler(factory, usdt, auction, AUCTIONEER);
        targetContract(address(handler));
    }

    function invariant_auctionBalanceShouldEqualTheDesiredAmountCompleted() public {
        uint256 auctionBalance = usdt.balanceOf(address(auction));
        uint256 totalBids = auction.getTotalBids();
        console.log("auctionBalance:", auctionBalance);

        if (uint256(auction.getState()) < 2) {
            uint256 totalRecordedAmounts = totalBids + AUCTION_PRICE + AMOUNT_DEPOSIT;
            console.log("totalRecordedAmounts:", totalRecordedAmounts);

            assertEq(auctionBalance, totalRecordedAmounts);
        }
        else {
            uint256 firstBidderWithdrawable = auction.getAmountWithdrawable(auction.getFirstBidder());
            uint256 secondBidderWithdrawable = auction.getAmountWithdrawable(auction.getSecondBidder());
            uint256 totalAmountWithdrawables = firstBidderWithdrawable + secondBidderWithdrawable;
            console.log("totalAmountWithdrawables:", totalAmountWithdrawables);

            uint256 discrepancy = _difference(auctionBalance, totalAmountWithdrawables);
            console.log("discrepancy: %s wei", discrepancy);

            /**
             * @custom:tolerance is very small amount of discrepancy (in wei) due to multiplication and division
             * @dev play with this value to see different results.
             * For example, you can set it to zero, means that the values should always be equal.
             * You might get an error that the values auctionBalance and totalAmountWithdrawables are
             * not equal with difference of 1 to 2 wei which is negligible in real world value.
             * 
             */
            uint256 tolerance = 2;
            assertLe(discrepancy, tolerance);
        }
    }

    function _abs(int256 amount) private pure returns(int256) {
        return amount >= 0 ? amount : -amount;
    }

    function _difference(uint256 amount0, uint256 amount1) private pure returns (uint256) {
        int256 diff = int256(int256(amount0) - int256(amount1));
        return uint256(_abs(diff));
    }
}
