// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployAuctionFactory} from "../../../script/DeployAuctionFactory.s.sol";
import {HundredDollarAuction} from "../../../src/HundredDollarAuction.sol";
import {AuctionFactory} from "../../../src/AuctionFactory.sol";
import {USDT} from "../../../src/USDT.sol";
import {HandlerActive} from "./HandlerActive.t.sol";

/**
 * Invariants:
 * 
 * State is active:
 * Auction Contract balance should always be equal to total bids + auction price + deposit amount
 * 
 */
contract InvariantsTestActiveAuction is StdInvariant, Test {
    DeployAuctionFactory deployer;
    AuctionFactory factory;
    HundredDollarAuction auction;
    USDT usdt;
    HandlerActive handler;
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

        handler = new HandlerActive(factory, usdt, auction, AUCTIONEER);
        targetContract(address(handler));
    }

    function invariant_auctionBalanceShouldEqualTheDesiredAmountActive() public {
        uint256 auctionBalance = usdt.balanceOf(address(auction));
        uint256 totalBids = auction.getTotalBids();
        console.log("auctionBalance:", auctionBalance);

        uint256 totalRecordedAmounts = totalBids + AUCTION_PRICE + AMOUNT_DEPOSIT;
        console.log("totalRecordedAmounts:", totalRecordedAmounts);

        assertEq(auctionBalance, totalRecordedAmounts);
    }
}
